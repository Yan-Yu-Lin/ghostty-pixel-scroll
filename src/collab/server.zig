//! Collab Server - TCP session host.
//!
//! Listens on a port, accepts guest connections, broadcasts presence
//! updates to all connected peers. One server per Ghostty session.
//! No cloud, no relay -- direct peer connection.

const std = @import("std");
const posix = std.posix;
const Allocator = std.mem.Allocator;
const global = @import("../global.zig");
const fd_io = @import("../os/fd.zig");
const px = @import("../os/posix_compat.zig");
const Profile = @import("profile.zig").Profile;
const protocol = @import("protocol.zig");
const Presence = protocol.Presence;

const log = std.log.scoped(.collab_server);

const MAX_PEERS = 8;

pub const Peer = struct {
    fd: posix.socket_t,
    profile: Profile,
    presence: Presence,
    connected: bool = true,
    read_buf: [4096]u8 = undefined,
    read_pos: u16 = 0,
};

pub const Server = struct {
    const Self = @This();

    alloc: Allocator,
    listener: ?std.Io.net.Server = null,
    peers: [MAX_PEERS]?Peer = .{null} ** MAX_PEERS,
    peer_count: u8 = 0,
    port: u16 = 0,
    session_token: [16]u8 = undefined,
    host_profile: Profile,
    thread: ?std.Thread = null,
    should_stop: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    /// Callback to deliver presence updates to the host renderer
    presence_callback: ?*const fn (peer_id: u8, presence: Presence, profile: Profile) void = null,
    join_callback: ?*const fn (profile: Profile) void = null,
    leave_callback: ?*const fn (peer_id: u8) void = null,

    pub fn init(alloc: Allocator, host_profile: Profile) Self {
        var server = Self{
            .alloc = alloc,
            .host_profile = host_profile,
        };
        // Generate random session token
        global.io().random(&server.session_token);
        return server;
    }

    pub fn deinit(self: *Self) void {
        self.stop();
        if (self.listener) |*listener| {
            listener.deinit(global.io());
            self.listener = null;
        }
        for (&self.peers) |*slot| {
            if (slot.*) |*peer| {
                fd_io.close(peer.fd);
                slot.* = null;
            }
        }
    }

    /// Start listening on a random available port.
    pub fn listen(self: *Self) !void {
        const address = try std.Io.net.IpAddress.parse("0.0.0.0", 0);
        self.listener = try address.listen(global.io(), .{
            .kernel_backlog = 8,
            .reuse_address = true,
        });
        self.port = self.listener.?.socket.address.getPort();

        log.info("collab server listening on port {d}", .{self.port});
    }

    /// Start the server thread.
    pub fn start(self: *Self) !void {
        self.thread = try std.Thread.spawn(.{}, serverLoop, .{self});
    }

    /// Stop the server thread.
    pub fn stop(self: *Self) void {
        self.should_stop.store(true, .release);
        if (self.thread) |t| {
            t.join();
            self.thread = null;
        }
    }

    /// Get the join code: ip:port for guests to connect.
    /// Detects the LAN IP so the code works across machines.
    pub fn getJoinCode(self: *const Self, buf: *[64]u8) u8 {
        // Detect LAN IP: create a UDP socket "connected" to 8.8.8.8:53,
        // then read the local address the kernel chose. No traffic is sent.
        var ip_str: [16]u8 = undefined;
        var ip_len: usize = 0;
        const bind_address = std.Io.net.IpAddress.parse("0.0.0.0", 0) catch {
            @memcpy(ip_str[0..9], "127.0.0.1");
            ip_len = 9;
            return self.formatJoinCode(buf, ip_str[0..ip_len]);
        };
        const udp_socket = bind_address.bind(global.io(), .{ .mode = .dgram }) catch {
            @memcpy(ip_str[0..9], "127.0.0.1");
            ip_len = 9;
            return self.formatJoinCode(buf, ip_str[0..ip_len]);
        };
        defer udp_socket.close(global.io());

        const dest = posix.sockaddr.in{
            .port = std.mem.nativeToBig(u16, 53),
            .addr = std.mem.nativeToBig(u32, (8 << 24) | (8 << 16) | (8 << 8) | 8), // 8.8.8.8
        };
        if (std.c.connect(udp_socket.handle, @ptrCast(&dest), @sizeOf(posix.sockaddr.in)) != 0) {
            @memcpy(ip_str[0..9], "127.0.0.1");
            ip_len = 9;
            return self.formatJoinCode(buf, ip_str[0..ip_len]);
        }

        var local_addr: posix.sockaddr.in = undefined;
        var addr_len: posix.socklen_t = @sizeOf(posix.sockaddr.in);
        if (std.c.getsockname(udp_socket.handle, @ptrCast(&local_addr), &addr_len) != 0) {
            @memcpy(ip_str[0..9], "127.0.0.1");
            ip_len = 9;
            return self.formatJoinCode(buf, ip_str[0..ip_len]);
        }

        // Convert the 4-byte address to dotted-decimal string
        const addr_bytes: [4]u8 = @bitCast(local_addr.addr);
        const result = std.fmt.bufPrint(&ip_str, "{d}.{d}.{d}.{d}", .{
            addr_bytes[0], addr_bytes[1], addr_bytes[2], addr_bytes[3],
        }) catch {
            @memcpy(ip_str[0..9], "127.0.0.1");
            ip_len = 9;
            return self.formatJoinCode(buf, ip_str[0..ip_len]);
        };
        ip_len = result.len;

        return self.formatJoinCode(buf, ip_str[0..ip_len]);
    }

    fn formatJoinCode(self: *const Self, buf: *[64]u8, ip: []const u8) u8 {
        const result = std.fmt.bufPrint(buf, "{s}:{d}", .{ ip, self.port }) catch return 0;
        return @intCast(result.len);
    }

    fn serverLoop(self: *Self) void {
        log.info("collab server thread started", .{});

        while (!self.should_stop.load(.acquire)) {
            // Accept new connections
            self.tryAccept();

            // Poll all peers for data
            self.pollPeers();

            // Small sleep to avoid spinning (1ms)
            std.Io.sleep(global.io(), .fromMilliseconds(1), .awake) catch {};
        }

        log.info("collab server thread stopped", .{});
    }

    fn tryAccept(self: *Self) void {
        const listen_fd = if (self.listener) |listener| listener.socket.handle else return;

        const result = px.acceptNonblocking(listen_fd) catch |err| {
            switch (err) {
                error.WouldBlock => return,
                else => {
                    log.warn("accept error: {}", .{err});
                    return;
                },
            }
        };

        // Find a free slot
        var slot_idx: ?u8 = null;
        for (&self.peers, 0..) |*slot, i| {
            if (slot.* == null) {
                slot_idx = @intCast(i);
                break;
            }
        }

        if (slot_idx) |idx| {
            self.peers[idx] = Peer{
                .fd = result,
                .profile = .{},
                .presence = .{},
            };
            self.peer_count += 1;
            log.info("new connection accepted (slot {d}, total {d})", .{ idx, self.peer_count });
        } else {
            log.warn("max peers reached, rejecting connection", .{});
            fd_io.close(result);
        }
    }

    fn pollPeers(self: *Self) void {
        for (&self.peers, 0..) |*slot, i| {
            const peer = &(slot.* orelse continue);
            if (!peer.connected) continue;

            // Try to read data
            const bytes_read = px.read(peer.fd, peer.read_buf[peer.read_pos..]) catch |err| {
                switch (err) {
                    error.WouldBlock => continue,
                    else => {
                        self.removePeer(@intCast(i));
                        continue;
                    },
                }
            };

            if (bytes_read == 0) {
                self.removePeer(@intCast(i));
                continue;
            }

            peer.read_pos += @intCast(bytes_read);

            // Process complete messages
            self.processMessages(@intCast(i));
        }
    }

    fn processMessages(self: *Self, peer_idx: u8) void {
        const peer = &(self.peers[peer_idx] orelse return);
        var consumed: u16 = 0;

        while (consumed < peer.read_pos) {
            const remaining = peer.read_buf[consumed..peer.read_pos];
            const header = protocol.decodeHeader(remaining) orelse break;

            const total_len: u16 = 3 + header.payload_len;
            if (remaining.len < total_len) break; // incomplete message

            const payload = remaining[3..total_len];
            self.handleMessage(peer_idx, header.msg_type, payload);
            consumed += total_len;
        }

        // Shift remaining data to front
        if (consumed > 0 and consumed < peer.read_pos) {
            const remaining = peer.read_pos - consumed;
            std.mem.copyForwards(u8, peer.read_buf[0..remaining], peer.read_buf[consumed..peer.read_pos]);
            peer.read_pos = remaining;
        } else if (consumed >= peer.read_pos) {
            peer.read_pos = 0;
        }
    }

    fn handleMessage(self: *Self, peer_idx: u8, msg_type: protocol.MessageType, payload: []const u8) void {
        switch (msg_type) {
            .join => {
                if (payload.len < 38) return;
                var profile = Profile.deserialize(payload[0..38]);
                profile.peer_id = peer_idx + 1; // 0 is reserved for host

                const peer = &(self.peers[peer_idx] orelse return);
                peer.profile = profile;

                log.info("peer joined: {s} (id={d})", .{ profile.getName(), profile.peer_id });

                // Send welcome with assigned peer_id
                self.sendWelcome(peer_idx);

                // Broadcast join to all other peers
                self.broadcastJoin(peer_idx);

                // Notify host
                if (self.join_callback) |cb| cb(profile);
            },
            .presence => {
                if (protocol.Presence.deserialize(payload)) |presence| {
                    const peer = &(self.peers[peer_idx] orelse return);
                    peer.presence = presence;

                    // Broadcast to all OTHER peers (not sender)
                    self.broadcastPresence(peer_idx, payload);

                    // Notify host renderer
                    if (self.presence_callback) |cb| cb(
                        peer.profile.peer_id,
                        presence,
                        peer.profile,
                    );
                }
            },
            .buffer_edit => {
                // Broadcast buffer edit to all OTHER peers (not sender)
                var msg_buf: [16400]u8 = undefined;
                if (protocol.encodeMessage(.buffer_edit, payload, &msg_buf)) |len| {
                    for (&self.peers, 0..) |*slot, i| {
                        if (i == peer_idx) continue;
                        const other = &(slot.* orelse continue);
                        if (!other.connected) continue;
                        fd_io.writeAll(other.fd, msg_buf[0..len]) catch {};
                    }
                }
                // Notify host to apply the edit locally
                if (protocol.BufferEdit.deserialize(payload)) |edit| {
                    const collab_main = @import("main.zig");
                    if (collab_main.CollabState.buffer_edit_callback) |cb| cb(edit);
                }
            },
            else => {},
        }
    }

    fn sendWelcome(self: *Self, peer_idx: u8) void {
        const peer = &(self.peers[peer_idx] orelse return);
        // Welcome payload: [1 assigned_peer_id][38 host_profile]
        var payload: [39]u8 = undefined;
        payload[0] = peer.profile.peer_id;
        self.host_profile.serialize(payload[1..39]);

        var msg_buf: [128]u8 = undefined;
        if (protocol.encodeMessage(.welcome, &payload, &msg_buf)) |len| {
            fd_io.writeAll(peer.fd, msg_buf[0..len]) catch {};
        }
    }

    fn broadcastJoin(self: *Self, new_peer_idx: u8) void {
        const new_peer = self.peers[new_peer_idx] orelse return;
        var payload: [38]u8 = undefined;
        new_peer.profile.serialize(&payload);

        var msg_buf: [128]u8 = undefined;
        const len = protocol.encodeMessage(.peer_joined, &payload, &msg_buf) orelse return;

        for (&self.peers, 0..) |*slot, i| {
            if (i == new_peer_idx) continue;
            const peer = &(slot.* orelse continue);
            if (!peer.connected) continue;
            fd_io.writeAll(peer.fd, msg_buf[0..len]) catch {};
        }
    }

    fn broadcastPresence(self: *Self, sender_idx: u8, payload: []const u8) void {
        var msg_buf: [512]u8 = undefined;
        const len = protocol.encodeMessage(.presence, payload, &msg_buf) orelse return;

        for (&self.peers, 0..) |*slot, i| {
            if (i == sender_idx) continue;
            const peer = &(slot.* orelse continue);
            if (!peer.connected) continue;
            fd_io.writeAll(peer.fd, msg_buf[0..len]) catch {};
        }
    }

    /// Broadcast the host's own presence to all connected peers.
    pub fn broadcastHostPresence(self: *Self, presence: Presence) void {
        var payload_buf: [512]u8 = undefined;
        const payload_len = presence.serialize(&payload_buf);
        if (payload_len == 0) return;

        var msg_buf: [512]u8 = undefined;
        const len = protocol.encodeMessage(.presence, payload_buf[0..payload_len], &msg_buf) orelse return;

        for (&self.peers) |*slot| {
            const peer = &(slot.* orelse continue);
            if (!peer.connected) continue;
            fd_io.writeAll(peer.fd, msg_buf[0..len]) catch {};
        }
    }

    /// Broadcast a raw pre-encoded message to all peers, optionally skipping a sender.
    pub fn broadcastRaw(self: *Self, msg: []const u8, skip_peer_id: u8) void {
        for (&self.peers) |*slot| {
            const peer = &(slot.* orelse continue);
            if (!peer.connected) continue;
            if (peer.profile.peer_id == skip_peer_id) continue;
            fd_io.writeAll(peer.fd, msg) catch {};
        }
    }

    fn removePeer(self: *Self, peer_idx: u8) void {
        const peer = self.peers[peer_idx] orelse return;
        log.info("peer disconnected: {s} (id={d})", .{ peer.profile.getName(), peer.profile.peer_id });

        // Notify host
        if (self.leave_callback) |cb| cb(peer.profile.peer_id);

        // Broadcast leave
        var payload: [1]u8 = .{peer.profile.peer_id};
        var msg_buf: [8]u8 = undefined;
        if (protocol.encodeMessage(.peer_left, &payload, &msg_buf)) |len| {
            for (&self.peers, 0..) |*slot, i| {
                if (i == peer_idx) continue;
                const other = &(slot.* orelse continue);
                if (!other.connected) continue;
                fd_io.writeAll(other.fd, msg_buf[0..len]) catch {};
            }
        }

        fd_io.close(peer.fd);
        self.peers[peer_idx] = null;
        if (self.peer_count > 0) self.peer_count -= 1;
    }
};
