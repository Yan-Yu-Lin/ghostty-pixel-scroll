const std = @import("std");

const posix = std.posix;

pub const Error = error{ WouldBlock, Interrupted, Unexpected };

fn errnoError() Error {
    return switch (std.c.errno(-1)) {
        .AGAIN => error.WouldBlock,
        .INTR => error.Interrupted,
        else => error.Unexpected,
    };
}

pub fn socket(domain: c_uint, socket_type: c_uint, protocol: c_uint) Error!posix.fd_t {
    const result = std.c.socket(domain, socket_type, protocol);
    if (result < 0) return errnoError();
    return result;
}

pub fn connect(fd: posix.fd_t, address: *const posix.sockaddr, len: posix.socklen_t) Error!void {
    if (std.c.connect(fd, address, len) != 0) return errnoError();
}

pub fn bind(fd: posix.fd_t, address: *const posix.sockaddr, len: posix.socklen_t) Error!void {
    if (std.c.bind(fd, address, len) != 0) return errnoError();
}

pub fn listen(fd: posix.fd_t, backlog: u31) Error!void {
    if (std.c.listen(fd, backlog) != 0) return errnoError();
}

pub fn setReuseAddress(fd: posix.fd_t) Error!void {
    const value: c_int = 1;
    if (std.c.setsockopt(fd, posix.SOL.SOCKET, posix.SO.REUSEADDR, &value, @sizeOf(c_int)) != 0) {
        return errnoError();
    }
}

pub fn getSockName(fd: posix.fd_t, address: *posix.sockaddr, len: *posix.socklen_t) Error!void {
    if (std.c.getsockname(fd, address, len) != 0) return errnoError();
}

pub fn acceptNonblocking(fd: posix.fd_t) Error!posix.fd_t {
    const result = std.c.accept4(fd, null, null, posix.SOCK.NONBLOCK);
    if (result < 0) return errnoError();
    return result;
}

pub fn poll(fds: []posix.pollfd, timeout_ms: c_int) Error!usize {
    const result = std.c.poll(fds.ptr, @intCast(fds.len), timeout_ms);
    if (result < 0) return errnoError();
    return @intCast(result);
}

pub fn read(fd: posix.fd_t, buffer: []u8) Error!usize {
    const result = std.c.read(fd, buffer.ptr, buffer.len);
    if (result < 0) return errnoError();
    return @intCast(result);
}

pub fn fork() Error!posix.pid_t {
    const result = std.c.fork();
    if (result < 0) return errnoError();
    return result;
}

pub fn dup2(old_fd: posix.fd_t, new_fd: posix.fd_t) Error!void {
    if (std.c.dup2(old_fd, new_fd) < 0) return errnoError();
}

pub fn chdir(path: []const u8) Error!void {
    var buffer: [std.fs.max_path_bytes:0]u8 = undefined;
    if (path.len >= buffer.len) return error.Unexpected;
    @memcpy(buffer[0..path.len], path);
    buffer[path.len] = 0;
    if (std.c.chdir(buffer[0..path.len :0]) != 0) return errnoError();
}

pub fn open(path: [*:0]const u8, flags: std.c.O, mode: std.c.mode_t) Error!posix.fd_t {
    const result = std.c.open(path, flags, mode);
    if (result < 0) return errnoError();
    return result;
}

pub fn kill(pid: posix.pid_t, signal: std.c.SIG) Error!void {
    if (std.c.kill(pid, signal) != 0) return errnoError();
}

pub const WaitResult = struct {
    pid: posix.pid_t,
    status: u32,
};

pub fn waitPidNoHang(pid: posix.pid_t) WaitResult {
    var status: c_int = 0;
    const result = std.c.waitpid(pid, &status, 1);
    return .{ .pid = result, .status = @bitCast(status) };
}

pub fn execvpeZ(
    file: [*:0]const u8,
    argv: [*:null]const ?[*:0]const u8,
    envp: [*:null]const ?[*:0]const u8,
) Error!void {
    if (execvpe(file, argv, envp) != 0) return errnoError();
}

pub fn exit(code: u8) noreturn {
    std.c._exit(code);
}

extern "c" fn execvpe(
    file: [*:0]const u8,
    argv: [*:null]const ?[*:0]const u8,
    envp: [*:null]const ?[*:0]const u8,
) c_int;
