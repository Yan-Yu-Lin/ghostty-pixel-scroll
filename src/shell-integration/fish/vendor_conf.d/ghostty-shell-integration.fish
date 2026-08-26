# This shell script aims to be written in a way where it can't really fail
# or all failure scenarios are handled, so that we never leave the shell in
# a weird state. If you find a way to break this, please report a bug!

function ghostty_restore_xdg_data_dir -d "restore the original XDG_DATA_DIR value"
    # If we don't have our own data dir then we don't need to do anything.
    if not set -q GHOSTTY_SHELL_INTEGRATION_XDG_DIR
        return
    end

    # If the data dir isn't set at all then we don't need to do anything.
    if not set -q XDG_DATA_DIRS
        return
    end

    # We need to do this so that XDG_DATA_DIRS turns into an array.
    set --function --path xdg_data_dirs "$XDG_DATA_DIRS"

    # If our data dir is in the list then remove it.
    if set --function index (contains --index "$GHOSTTY_SHELL_INTEGRATION_XDG_DIR" $xdg_data_dirs)
        set --erase --function xdg_data_dirs[$index]
    end

    # Re-export our data dir
    if set -q xdg_data_dirs[1]
        set --global --export --unpath XDG_DATA_DIRS "$xdg_data_dirs"
    else
        set --erase --global XDG_DATA_DIRS
    end

    set --erase GHOSTTY_SHELL_INTEGRATION_XDG_DIR
end

function ghostty_exit -d "exit the shell integration setup"
    functions -e ghostty_restore_xdg_data_dir
    functions -e ghostty_exit
    exit 0
end

# We always try to restore the XDG data dir
ghostty_restore_xdg_data_dir

# If we aren't interactive or we've already run, don't run.
status --is-interactive || ghostty_exit

# We do the full setup on the first prompt render. We do this so that other
# shell integrations that setup the prompt and modify things are able to run
# first. We want to run _last_.
function __ghostty_setup --on-event fish_prompt -d "Setup ghostty integration"
    functions -e __ghostty_setup

    set --local features (string split , $GHOSTTY_SHELL_FEATURES)

    # Parse the fish version for feature detection.
    # Default to 0.0 if version is unavailable or malformed.
    set -l fish_major 0
    set -l fish_minor 0
    if set -q version[1]
        set -l fish_ver (string match -r '(\d+)\.(\d+)' -- $version[1])
        if set -q fish_ver[2]; and test -n "$fish_ver[2]"
            set fish_major "$fish_ver[2]"
        end
        if set -q fish_ver[3]; and test -n "$fish_ver[3]"
            set fish_minor "$fish_ver[3]"
        end
    end

    # Our OSC133A (prompt start) sequence. If we're using Fish >= 4.1
    # then it supports click_events so we enable that.
    set -g __ghostty_prompt_start_mark "\e]133;A\a"
    if test "$fish_major" -gt 4; or test "$fish_major" -eq 4 -a "$fish_minor" -ge 1
        set -g __ghostty_prompt_start_mark "\e]133;A;click_events=1\a"
    end

    if string match -q 'cursor*' -- $features
        set -l cursor 5                                   # blinking bar
        contains cursor:steady $features && set cursor 6  # steady bar

        # Change the cursor to a beam on prompt.
        function __ghostty_set_cursor_beam --on-event fish_prompt -V cursor -d "Set cursor shape"
            if not functions -q fish_vi_cursor_handle
                echo -en "\e[$cursor q"
            end
        end
        function __ghostty_reset_cursor --on-event fish_preexec -d "Reset cursor shape"
            if not functions -q fish_vi_cursor_handle
                echo -en "\e[0 q"
            end
        end
    end

    # Add Ghostty binary to PATH if the path feature is enabled
    if contains path $features; and test -n "$GHOSTTY_BIN_DIR"
        fish_add_path --global --path --append "$GHOSTTY_BIN_DIR"
    end

    # When using sudo shell integration feature, ensure $TERMINFO is set
    # and `sudo` is not already a function or alias
    if contains sudo $features; and test -n "$TERMINFO"; and test file = (type -t sudo 2> /dev/null; or echo "x")
        # Wrap `sudo` command to ensure Ghostty terminfo is preserved
        function sudo -d "Wrap sudo to preserve terminfo"
            set --function sudo_has_sudoedit_flags no
            for arg in $argv
                # Check if argument is '-e' or '--edit' (sudoedit flags)
                if string match -q -- -e "$arg"; or string match -q -- --edit "$arg"
                    set --function sudo_has_sudoedit_flags yes
                    break
                end
                # Check if argument is neither an option nor a key-value pair
                if not string match -r -q -- "^-" "$arg"; and not string match -r -q -- "=" "$arg"
                    break
                end
            end
            if test "$sudo_has_sudoedit_flags" = yes
                command sudo $argv
            else
                command sudo --preserve-env=TERMINFO $argv
            end
        end
    end

    # SSH Integration
    #
    # Wrap `ssh` with `ghostty +ssh` and translate the shell-integration
    # feature flags into command options.
    set -l features (string split ',' -- "$GHOSTTY_SHELL_FEATURES")
    if contains ssh-env $features; or contains ssh-terminfo $features
        function ssh --wraps=ssh --description "SSH wrapper with Ghostty integration"
            set -l features (string split ',' -- "$GHOSTTY_SHELL_FEATURES")
            set -l flags
            contains ssh-env $features; or set -a flags --forward-env=false
            contains ssh-terminfo $features; or set -a flags --terminfo=false
            "$GHOSTTY_BIN_DIR/ghostty" +ssh $flags -- $argv
        end
    end

    # Setup prompt marking
    function __ghostty_mark_prompt_start --on-event fish_prompt --on-event fish_posterror
        # If we never got the output end event, then we need to send it now.
        if test "$__ghostty_prompt_state" != prompt-start
            echo -en "\e]133;D\a"
        end

        set --global __ghostty_prompt_state prompt-start
        echo -en $__ghostty_prompt_start_mark
    end

    function __ghostty_mark_output_start --on-event fish_preexec
        set --global __ghostty_prompt_state pre-exec
        echo -en "\e]133;C\a"
    end

    function __ghostty_mark_output_end --on-event fish_postexec
        set --global __ghostty_prompt_state post-exec
        echo -en "\e]133;D;$status\a"
    end

    # Report pwd. This is actually built-in to fish but only for terminals
    # that match an allowlist and that isn't us.
    function __update_cwd_osc --on-variable PWD -d 'Notify capable terminals when $PWD changes'
        if status --is-command-substitution || set -q INSIDE_EMACS
            return
        end
        printf \e\]7\;file://%s%s\a $hostname (string escape --style=url $PWD)
    end

    # Enable fish to handle reflow because Ghostty clears the prompt on resize.
    set --global fish_handle_reflow 1

    # Initial calls for first prompt
    if string match -q 'cursor*' -- $features
        __ghostty_set_cursor_beam
    end
    __ghostty_mark_prompt_start
    __update_cwd_osc
end

ghostty_exit

# Neovim GUI mode: create a shell function that sends OSC 1338 to switch
# the current terminal into Ghostty's native Neovim GUI renderer.
# The function name is configurable via neovim-gui-alias (default: nvim-gui).
if set -q GHOSTTY_NVIM_GUI_ALIAS; and test -n "$GHOSTTY_NVIM_GUI_ALIAS"
    eval "function $GHOSTTY_NVIM_GUI_ALIAS; printf '\\e]1338\\a'; end"
end

function ghostty-shaders
    echo "Ghostty shader presets:"
    echo "  crt-curved      (curved CRT preset)"
    echo "  crt-curve       (curve-only overlay, for stacking)"
    echo "  phosphor-green  (flat green phosphor)"
    echo "  blue-neon-grid  (flat blue/magenta cyber)"
    echo "  amber-console   (flat amber monochrome)"
    echo "  hud-diagnostic  (flat dark HUD)"
    echo "  combine with +  (example: phosphor-green+crt-curve)"
    echo "  none            (disable custom shaders)"
end

function ghostty-shader
    if test (count $argv) -eq 0
        ghostty-shaders
        echo "Usage: ghostty-shader <preset...>"
        return 0
    end

    set -l preset (string join + $argv)
    if test "$preset" = "list" -o "$preset" = "--list"
        ghostty-shaders
        return 0
    end

    printf '\e]1345;%s\a' "$preset"
end

# Collab session commands
function ghostty-share
    set -l share_dir (test (count $argv) -gt 0; and echo $argv[1]; or echo ".")
    set share_dir (cd "$share_dir" 2>/dev/null; and pwd)

    printf '\e]1342\a'
    sleep 0.3
    if test -f /tmp/ghostty-collab-info
        set -l addr (cat /tmp/ghostty-collab-info)
        set -l port (string split ':' $addr)[-1]
        set -l local_ip (hostname -I 2>/dev/null | awk '{print $1}')
        test -z "$local_ip"; and set local_ip (ipconfig getifaddr en0 2>/dev/null)
        test -z "$local_ip"; and set local_ip "<your-ip>"

        echo "$share_dir" > /tmp/ghostty-collab-share-dir

        echo "=== Ghostty Collab Session Started ==="
        echo ""
        echo "Sharing: $share_dir"
        echo ""
        echo "--- Join Options ---"
        echo ""
        echo "1) Same machine (shared Neovim, host config):"
        echo "   ghostty-join 127.0.0.1:$port"
        echo "   Both edit in the same Neovim instance. Instant, zero latency."
        echo "   Guest uses YOUR Neovim config/plugins."
        echo ""
        echo "2) Remote, host config (guest connects to your Neovim):"
        echo "   ghostty-join $local_ip:$port"
        echo "   Guest connects to your Neovim over the network."
        echo "   Guest uses YOUR config. ~1ms latency on LAN."
        echo ""
        echo "3) Remote, own config (SSHFS mount):"
        echo "   ghostty-join (whoami)@$local_ip:$port"
        echo "   Guest runs THEIR OWN Neovim with their config/plugins/LSP."
        echo "   Your files are mounted on their machine via SSHFS."
        echo "   Live edits synced character-by-character."
        echo ""
        echo "--- Requirements ---"
        echo "Option 1: Nothing extra."
        echo "Option 2: Guest can reach $local_ip:$port (same LAN or port forward)."
        echo "Option 3: Guest needs 'sshfs' + SSH access to (whoami)@$local_ip."
        echo "  Install sshfs:"
        echo "    Ubuntu/Debian: sudo apt install sshfs"
        echo "    Arch:          sudo pacman -S sshfs"
        echo "    Fedora:        sudo dnf install fuse-sshfs"
        echo "    macOS:         brew install macfuse sshfs"
        echo "    NixOS:         nix-env -iA nixpkgs.sshfs"
        echo ""
        echo "==================================="
    end
end

function ghostty-join
    if test (count $argv) -eq 0
        echo "Usage: ghostty-join [user@]host:port"
        return 1
    end

    set -l target $argv[1]
    set -l user ""
    set -l host ""
    set -l port ""

    if string match -q '*@*' $target
        set user (string split '@' $target)[1]
        set -l hostport (string split '@' $target)[2]
        set host (string split ':' $hostport)[1]
        set port (string split ':' $hostport)[-1]
    else
        set host (string split ':' $target)[1]
        set port (string split ':' $target)[-1]
    end

    echo "Connecting to collab session at $host:$port..."
    printf '\e]1343;%s:%s\a' $host $port

    if test -n "$user"
        if not command -v sshfs &>/dev/null
            echo "Error: sshfs is required for remote collab."
            echo "  Ubuntu/Debian: sudo apt install sshfs"
            echo "  Arch:          sudo pacman -S sshfs"
            echo "  macOS:         brew install macfuse sshfs"
            return 1
        end

        set -l share_dir (ssh -o ConnectTimeout=5 -o ConnectionAttempts=2 \
            -o StrictHostKeyChecking=accept-new \
            -o PreferredAuthentications=publickey,keyboard-interactive,password \
            "$user@$host" \
            "cat /tmp/ghostty-collab-share-dir 2>/dev/null" 2>/dev/null)
        test -z "$share_dir"; and set share_dir "/home/$user"

        set -l mount_dir "/tmp/ghostty-collab-mount-%self"
        mkdir -p "$mount_dir"

        echo "Mounting $user@$host:$share_dir ..."
        sshfs "$user@$host:$share_dir" "$mount_dir" \
            -o StrictHostKeyChecking=accept-new \
            -o ConnectTimeout=5 \
            -o PreferredAuthentications=publickey,keyboard-interactive,password \
            -o reconnect \
            -o ServerAliveInterval=15 -o cache=yes -o kernel_cache \
            -o auto_cache -o compression=no 2>/dev/null

        if test $status -ne 0
            echo "Error: SSHFS mount failed."
            rmdir "$mount_dir" 2>/dev/null
            return 1
        end

        echo "$mount_dir" > /tmp/ghostty-collab-mount
        echo "$share_dir" > /tmp/ghostty-collab-remote-share-dir
        echo "Mounted! cd $mount_dir to start editing."
        echo "Live edits synced in real-time over collab TCP."
        echo "To disconnect: ghostty-leave"
        cd "$mount_dir"
    else
        set -l nvim_port (math $port + 1)
        echo "Connecting to host Neovim at $host:$nvim_port..."
        sleep 0.3
        printf '\e]1344;%s:%s\a' $host $nvim_port
        echo ""
        echo "=== Joined Collab Session ==="
        echo "Connected to $host:$port"
        echo "You are now sharing cursors with the host."
        echo "Your cursor is visible to other participants."
        echo ""
        echo "To disconnect: ghostty-leave"
        echo "============================="
    end
end

function ghostty-leave
    if test -f /tmp/ghostty-collab-mount
        set -l mount_dir (cat /tmp/ghostty-collab-mount)
        if test -n "$mount_dir" -a -d "$mount_dir"
            fusermount -u "$mount_dir" 2>/dev/null; or umount "$mount_dir" 2>/dev/null
            rmdir "$mount_dir" 2>/dev/null
        end
        rm -f /tmp/ghostty-collab-mount
    end
    echo "Disconnected."
end
