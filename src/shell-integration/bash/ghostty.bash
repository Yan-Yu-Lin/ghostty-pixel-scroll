# Parts of this script are based on Kitty's bash integration. Kitty is
# distributed under GPLv3, so this file is also distributed under GPLv3.
# The license header is reproduced below:
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# We need to be in interactive mode to proceed.
if [[ "$-" != *i* ]]; then builtin return; fi

# When automatic shell integration is active, we were started in POSIX
# mode and need to manually recreate the bash startup sequence.
if [ -n "$GHOSTTY_BASH_INJECT" ]; then
  # Store a temporary copy of our startup flags and unset these global
  # environment variables so we can safely handle reentrancy.
  builtin declare __ghostty_bash_flags="$GHOSTTY_BASH_INJECT"
  builtin unset ENV GHOSTTY_BASH_INJECT

  # Restore an existing ENV that was replaced by the shell integration code.
  if [[ -n "$GHOSTTY_BASH_ENV" ]]; then
    builtin export ENV=$GHOSTTY_BASH_ENV
    builtin unset GHOSTTY_BASH_ENV
  fi

  # Restore bash's default 'posix' behavior. Also reset 'inherit_errexit',
  # which doesn't happen as part of the 'posix' reset.
  builtin set +o posix
  builtin shopt -u inherit_errexit 2>/dev/null

  # Unexport HISTFILE if it was set by the shell integration code.
  if [[ -n "$GHOSTTY_BASH_UNEXPORT_HISTFILE" ]]; then
    builtin export -n HISTFILE
    builtin unset GHOSTTY_BASH_UNEXPORT_HISTFILE
  fi

  # Manually source the startup files. See INVOCATION in bash(1) and
  # run_startup_files() in shell.c in the Bash source code.
  if builtin shopt -q login_shell; then
    if [[ $__ghostty_bash_flags != *"--noprofile"* ]]; then
      [ -r /etc/profile ] && builtin source "/etc/profile"
      for __ghostty_rcfile in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
        [ -r "$__ghostty_rcfile" ] && {
          builtin source "$__ghostty_rcfile"
          break
        }
      done
    fi
  else
    if [[ $__ghostty_bash_flags != *"--norc"* ]]; then
      # The location of the system bashrc is determined at bash build
      # time via -DSYS_BASHRC and can therefore vary across distros:
      #  Arch, Debian, Ubuntu use /etc/bash.bashrc
      #  Fedora uses /etc/bashrc sourced from ~/.bashrc instead of SYS_BASHRC
      #  Void Linux uses /etc/bash/bashrc
      #  Nixos uses /etc/bashrc
      for __ghostty_rcfile in /etc/bash.bashrc /etc/bash/bashrc /etc/bashrc; do
        [ -r "$__ghostty_rcfile" ] && {
          builtin source "$__ghostty_rcfile"
          break
        }
      done
      if [[ -z "$GHOSTTY_BASH_RCFILE" ]]; then GHOSTTY_BASH_RCFILE="$HOME/.bashrc"; fi
      [ -r "$GHOSTTY_BASH_RCFILE" ] && builtin source "$GHOSTTY_BASH_RCFILE"
    fi
  fi

  builtin unset __ghostty_rcfile
  builtin unset __ghostty_bash_flags
  builtin unset GHOSTTY_BASH_RCFILE
fi

# Add Ghostty binary to PATH if the path feature is enabled
if [[ "$GHOSTTY_SHELL_FEATURES" == *"path"* && -n "$GHOSTTY_BIN_DIR" ]]; then
  if [[ ":$PATH:" != *":$GHOSTTY_BIN_DIR:"* ]]; then
    export PATH="$PATH:$GHOSTTY_BIN_DIR"
  fi
fi

# Sudo
if [[ "$GHOSTTY_SHELL_FEATURES" == *"sudo"* && -n "$TERMINFO" ]]; then
  # Wrap `sudo` command to ensure Ghostty terminfo is preserved.
  #
  # This approach supports wrapping a `sudo` alias, but the alias definition
  # must come _after_ this function is defined. Otherwise, the alias expansion
  # will take precedence over this function, and it won't be wrapped.
  function sudo {
    builtin local sudo_has_sudoedit_flags="no"
    for arg in "$@"; do
      # Check if argument is '-e' or '--edit' (sudoedit flags)
      if [[ "$arg" == "-e" || $arg == "--edit" ]]; then
        sudo_has_sudoedit_flags="yes"
        builtin break
      fi
      # Check if argument is neither an option nor a key-value pair
      if [[ "$arg" != -* && "$arg" != *=* ]]; then
        builtin break
      fi
    done
    if [[ "$sudo_has_sudoedit_flags" == "yes" ]]; then
      builtin command sudo "$@"
    else
      builtin command sudo --preserve-env=TERMINFO "$@"
    fi
  }
fi

# SSH Integration
#
# Wrap `ssh` with `ghostty +ssh` and translate the shell-integration
# feature flags into command options.
if [[ "$GHOSTTY_SHELL_FEATURES" == *ssh-* ]]; then
  function ssh() {
    builtin local -a flags
    flags=()
    [[ "$GHOSTTY_SHELL_FEATURES" != *ssh-env* ]] && flags+=(--forward-env=false)
    [[ "$GHOSTTY_SHELL_FEATURES" != *ssh-terminfo* ]] && flags+=(--terminfo=false)
    "$GHOSTTY_BIN_DIR/ghostty" +ssh "${flags[@]}" -- "$@"
  }
fi

# This is set to 1 when we're executing a command so that we don't
# send prompt marks multiple times.
_ghostty_executing=""
_ghostty_last_reported_cwd=""

function __ghostty_precmd() {
  local ret="$?"
  if test "$_ghostty_executing" != "0"; then
    _GHOSTTY_SAVE_PS1="$PS1"
    _GHOSTTY_SAVE_PS2="$PS2"

    # Use 133;P (not 133;A) inside PS1 to avoid fresh-line behavior on
    # readline redraws (e.g., vi mode switches, Ctrl-L). The initial
    # 133;A with fresh-line is emitted once via printf below.
    PS1='\[\e]133;P;k=i\a\]'$PS1'\[\e]133;B\a\]'
    PS2='\[\e]133;P;k=s\a\]'$PS2'\[\e]133;B\a\]'

    # Bash doesn't redraw the leading lines in a multiline prompt so we mark
    # the start of each line (after each newline) as a secondary prompt. This
    # correctly handles multiline prompts by setting the first to primary and
    # the subsequent lines to secondary.
    #
    # We only replace the \n prompt escape, not literal newlines ($'\n'),
    # because literal newlines may appear inside $(...) command substitutions
    # where inserting escape sequences would break shell syntax.
    if [[ "$PS1" == *"\n"* ]]; then
      PS1="${PS1//\\n/\\n$'\\[\\e]133;P;k=s\\a\\]'}"
    fi

    # Cursor
    if [[ "$GHOSTTY_SHELL_FEATURES" == *"cursor"* ]]; then
      builtin local cursor=5  # blinking bar
      [[ "$GHOSTTY_SHELL_FEATURES" == *"cursor:steady"* ]] && cursor=6  # steady bar

      [[ "$PS1" != *"\[\e[${cursor} q\]"* ]] && PS1=$PS1"\[\e[${cursor} q\]"
      [[ "$PS0" != *'\[\e[0 q\]'* ]] && PS0=$PS0'\[\e[0 q\]' # reset
    fi

    # Title (working directory)
    if [[ "$GHOSTTY_SHELL_FEATURES" == *"title"* ]]; then
      PS1=$PS1'\[\e]2;\w\a\]'
    fi
  fi

  if test "$_ghostty_executing" != ""; then
    # End of current command. Report its status.
    builtin printf "\e]133;D;%s;aid=%s\a" "$ret" "$BASHPID"
  fi

  # Fresh line and start of prompt. When ble.sh is active, emit 133;P instead
  # of 133;A because ble.sh maintains its own cursor position tracking. 133;A's
  # cursor movement (CR+LF when not at column 0) is invisible to ble.sh and
  # desyncs its position state, causing display artifacts like duplicate
  # prompts. See: https://github.com/akinomyoga/ble.sh/issues/684
  if [[ -n "${BLE_VERSION-}" ]]; then
    builtin printf "\e]133;P;k=i\a"
  else
    builtin printf "\e]133;A;redraw=last;cl=line;aid=%s\a" "$BASHPID"
  fi

  # unfortunately bash provides no hooks to detect cwd changes
  # in particular this means cwd reporting will not happen for a
  # command like cd /test && cat. PS0 is evaluated before cd is run.
  if [[ "$_ghostty_last_reported_cwd" != "$PWD" ]]; then
    _ghostty_last_reported_cwd="$PWD"
    builtin printf "\e]7;kitty-shell-cwd://%s%s\a" "$HOSTNAME" "$PWD"
  fi

  _ghostty_executing=0
}

function __ghostty_preexec() {
  builtin local cmd="$1"

  PS1="$_GHOSTTY_SAVE_PS1"
  PS2="$_GHOSTTY_SAVE_PS2"

  # Title (current command)
  if [[ -n $cmd && "$GHOSTTY_SHELL_FEATURES" == *"title"* ]]; then
    builtin printf "\e]2;%s\a" "${cmd//[[:cntrl:]]/}"
  fi

  # End of input, start of output.
  builtin printf "\e]133;C;\a"
  _ghostty_executing=1
}

if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) )); then
  __ghostty_preexec_hook() {
    builtin local cmd
    cmd=$(LC_ALL=C HISTTIMEFORMAT='' builtin history 1)
    cmd="${cmd#*[[:digit:]][* ] }"
    [[ -n "$cmd" ]] && __ghostty_preexec "$cmd"
  }

  __ghostty_hook() {
    builtin local ret=$?
    __ghostty_precmd "$ret"

    if [[ "$PS0" != *"__ghostty_preexec_hook"* ]]; then
      if (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 3) )); then
        PS0+='${ __ghostty_preexec_hook; }'
      else
        PS0+='$(__ghostty_preexec_hook >/dev/tty)'
      fi
    fi
  }

  if [[ ";${PROMPT_COMMAND[*]:-};" != *";__ghostty_hook 2>/dev/null;"* ]]; then
    if [[ -z "${PROMPT_COMMAND[*]}" ]]; then
      if (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) )); then
        PROMPT_COMMAND=("__ghostty_hook 2>/dev/null")
      else
        PROMPT_COMMAND="__ghostty_hook 2>/dev/null"
      fi
    elif [[ $(builtin declare -p PROMPT_COMMAND 2>/dev/null) == "declare -a "* ]]; then
      PROMPT_COMMAND+=("__ghostty_hook 2>/dev/null")
    else
      [[ "${PROMPT_COMMAND}" =~ (\;[[:space:]]*|$'\n')$ ]] || PROMPT_COMMAND+=";"
      PROMPT_COMMAND+="__ghostty_hook 2>/dev/null"
    fi
  fi
else
  builtin source "$(dirname -- "${BASH_SOURCE[0]}")/bash-preexec.sh"
  preexec_functions+=(__ghostty_preexec)
  precmd_functions+=(__ghostty_precmd)
fi

# Neovim GUI mode: create a shell function that sends OSC 1338 to switch
# the current terminal into Ghostty's native Neovim GUI renderer.
# The function name is configurable via neovim-gui-alias (default: nvim-gui).
if [[ -n "$GHOSTTY_NVIM_GUI_ALIAS" ]]; then
    eval "${GHOSTTY_NVIM_GUI_ALIAS}() { builtin printf '\\e]1338\\a'; }"
fi

ghostty-shaders() {
    builtin echo "Ghostty shader presets:"
    builtin echo "  crt-curved      (curved CRT preset)"
    builtin echo "  crt-curve       (curve-only overlay, for stacking)"
    builtin echo "  phosphor-green  (flat green phosphor)"
    builtin echo "  blue-neon-grid  (flat blue/magenta cyber)"
    builtin echo "  amber-console   (flat amber monochrome)"
    builtin echo "  hud-diagnostic  (flat dark HUD)"
    builtin echo "  combine with +  (example: phosphor-green+crt-curve)"
    builtin echo "  none            (disable custom shaders)"
}

ghostty-shader() {
    local preset="$1"
    if (( $# > 1 )); then
        preset="${*// /+}"
    fi
    if [[ -z "$preset" || "$preset" == "list" || "$preset" == "--list" ]]; then
        ghostty-shaders
        [[ -z "$preset" ]] && builtin echo "Usage: ghostty-shader <preset...>"
        return 0
    fi

    builtin printf '\e]1345;%s\a' "$preset"
}

# Collab session commands: ghostty-share starts hosting, ghostty-join connects.
ghostty-share() {
    local share_dir="${1:-.}"
    share_dir="$(cd "$share_dir" 2>/dev/null && pwd)"

    builtin printf '\e]1342\a'
    sleep 0.3
    if [[ -f /tmp/ghostty-collab-info ]]; then
        local addr port local_ip
        addr=$(< /tmp/ghostty-collab-info)
        port="${addr##*:}"
        local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        [[ -z "$local_ip" ]] && local_ip=$(ipconfig getifaddr en0 2>/dev/null)
        [[ -z "$local_ip" ]] && local_ip="<your-ip>"

        # Store shared directory path for guests
        builtin echo "$share_dir" > /tmp/ghostty-collab-share-dir

        builtin echo "=== Ghostty Collab Session Started ==="
        builtin echo ""
        builtin echo "Sharing: $share_dir"
        builtin echo ""
        builtin echo "--- Join Options ---"
        builtin echo ""
        builtin echo "1) Same machine (shared Neovim, host config):"
        builtin echo "   ghostty-join 127.0.0.1:${port}"
        builtin echo "   Both edit in the same Neovim instance. Instant, zero latency."
        builtin echo "   Guest uses YOUR Neovim config/plugins."
        builtin echo ""
        builtin echo "2) Remote, host config (guest connects to your Neovim):"
        builtin echo "   ghostty-join ${local_ip}:${port}"
        builtin echo "   Guest connects to your Neovim over the network."
        builtin echo "   Guest uses YOUR config. ~1ms latency on LAN."
        builtin echo ""
        builtin echo "3) Remote, own config (SSHFS mount):"
        builtin echo "   ghostty-join $(whoami)@${local_ip}:${port}"
        builtin echo "   Guest runs THEIR OWN Neovim with their config/plugins/LSP."
        builtin echo "   Your files are mounted on their machine via SSHFS."
        builtin echo "   Live edits synced character-by-character."
        builtin echo ""
        builtin echo "--- Requirements ---"
        builtin echo "Option 1: Nothing extra."
        builtin echo "Option 2: Guest can reach ${local_ip}:${port} (same LAN or port forward)."
        builtin echo "Option 3: Guest needs 'sshfs' + SSH access to $(whoami)@${local_ip}."
        builtin echo "  Install sshfs:"
        builtin echo "    Ubuntu/Debian: sudo apt install sshfs"
        builtin echo "    Arch:          sudo pacman -S sshfs"
        builtin echo "    Fedora:        sudo dnf install fuse-sshfs"
        builtin echo "    macOS:         brew install macfuse sshfs"
        builtin echo "    NixOS:         nix-env -iA nixpkgs.sshfs"
        builtin echo ""
        builtin echo "==================================="
    fi
}
ghostty-join() {
    if [[ -z "$1" ]]; then
        builtin echo "Usage: ghostty-join [user@]host:port"
        builtin echo ""
        builtin echo "  Local:  ghostty-join 192.168.1.50:34399"
        builtin echo "  Remote: ghostty-join parker@192.168.1.50:34399"
        return 1
    fi

    local target="$1"
    local user="" host="" port=""

    # Parse user@host:port or host:port
    if [[ "$target" == *@* ]]; then
        user="${target%%@*}"
        local hostport="${target#*@}"
        host="${hostport%%:*}"
        port="${hostport##*:}"
    else
        host="${target%%:*}"
        port="${target##*:}"
    fi

    if [[ -z "$host" || -z "$port" ]]; then
        builtin echo "Invalid format. Usage: ghostty-join [user@]host:port"
        return 1
    fi

    # Step 1: Join collab session (presence/cursors)
    builtin echo "Connecting to collab session at ${host}:${port}..."
    builtin printf '\e]1343;%s:%s\a' "$host" "$port"

    if [[ -n "$user" ]]; then
        # Remote mode: SSHFS mount + local Neovim with own config

        # Check for sshfs
        if ! command -v sshfs &>/dev/null; then
            builtin echo "Error: sshfs is required for remote collab."
            builtin echo ""
            builtin echo "Install it:"
            builtin echo "  Ubuntu/Debian: sudo apt install sshfs"
            builtin echo "  Arch:          sudo pacman -S sshfs"
            builtin echo "  Fedora:        sudo dnf install fuse-sshfs"
            builtin echo "  macOS:         brew install macfuse sshfs"
            builtin echo "  NixOS:         nix-env -iA nixpkgs.sshfs"
            return 1
        fi

        # Get the shared directory from host
        local share_dir
        share_dir=$(ssh -o ConnectTimeout=5 -o ConnectionAttempts=2 \
            -o StrictHostKeyChecking=accept-new \
            -o PreferredAuthentications=publickey,keyboard-interactive,password \
            "${user}@${host}" \
            "cat /tmp/ghostty-collab-share-dir 2>/dev/null" 2>/dev/null)

        if [[ -z "$share_dir" ]]; then
            builtin echo "Warning: Could not detect shared directory. Using home dir."
            share_dir="/home/${user}"
        fi

        # Mount point
        local mount_dir="/tmp/ghostty-collab-mount-$$"
        mkdir -p "$mount_dir"

        builtin echo "Mounting ${user}@${host}:${share_dir} ..."

        sshfs "${user}@${host}:${share_dir}" "$mount_dir" \
            -o StrictHostKeyChecking=accept-new \
            -o ConnectTimeout=5 \
            -o PreferredAuthentications=publickey,keyboard-interactive,password \
            -o reconnect \
            -o ServerAliveInterval=15 \
            -o cache=yes \
            -o auto_cache

        if [[ $? -ne 0 ]]; then
            builtin echo ""
            builtin echo "Error: SSHFS mount failed."
            builtin echo "Troubleshooting:"
            builtin echo "  1. Can you SSH? Try: ssh ${user}@${host}"
            builtin echo "  2. Does the path exist? ${share_dir}"
            builtin echo "  3. Is FUSE available? Check: ls /dev/fuse"
            builtin echo "  4. On NixOS, add 'programs.fuse.userAllowOther = true;' to config"
            rmdir "$mount_dir" 2>/dev/null
            return 1
        fi

        builtin echo "Mounted! Files available at: $mount_dir"
        builtin echo ""
        builtin echo "Your Neovim, your config, their files."
        builtin echo "Live edits synced in real-time over collab TCP."
        builtin echo ""
        builtin echo "To disconnect: ghostty-leave"

        # Store mount info for cleanup
        builtin echo "$mount_dir" > /tmp/ghostty-collab-mount

        # Store the share dir so Ghostty can compute relative paths
        builtin echo "$share_dir" > /tmp/ghostty-collab-remote-share-dir

        # cd into the mounted directory
        cd "$mount_dir" || true
    else
        # Local mode: connect to host's Neovim directly (same machine)
        local nvim_port=$((port + 1))
        builtin echo "Connecting to host Neovim at ${host}:${nvim_port}..."
        sleep 0.3
        builtin printf '\e]1344;%s:%s\a' "$host" "$nvim_port"
        builtin echo ""
        builtin echo "=== Joined Collab Session ==="
        builtin echo "Connected to ${host}:${port}"
        builtin echo "You are now sharing cursors with the host."
        builtin echo "Your cursor is visible to other participants."
        builtin echo ""
        builtin echo "To disconnect: ghostty-leave"
        builtin echo "============================="
    fi
}

# Disconnect from collab session and clean up
ghostty-leave() {
    if [[ -f /tmp/ghostty-collab-mount ]]; then
        local mount_dir
        mount_dir=$(< /tmp/ghostty-collab-mount)
        if [[ -n "$mount_dir" && -d "$mount_dir" ]]; then
            builtin echo "Unmounting $mount_dir ..."
            fusermount -u "$mount_dir" 2>/dev/null || umount "$mount_dir" 2>/dev/null
            rmdir "$mount_dir" 2>/dev/null
        fi
        rm -f /tmp/ghostty-collab-mount
    fi
    builtin echo "Disconnected from collab session."
}
