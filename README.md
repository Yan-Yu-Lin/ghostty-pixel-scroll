<h1>
<p align="center">
  Ghostty Pixel Scroll
  <br>
  <sub>A GPU-accelerated development environment</sub>
</p>
</h1>
<p align="center">
  A fun project born from loving <a href="https://github.com/neovide/neovide">Neovide</a> but wanting it to live inside the terminal.
  <br>
  Built on <a href="https://github.com/ghostty-org/ghostty">Ghostty's</a> terminal engine by Mitchell Hashimoto.
  <br><br>
  <a href="#what-is-this">What is this?</a>
  &middot;
  <a href="#features">Features</a>
  &middot;
  <a href="#quick-start">Quick Start</a>
  &middot;
  <a href="#install">Install</a>
  &middot;
  <a href="#building">Building</a>
  &middot;
  <a href="#configuration">Configuration</a>
</p>

---

## What is this?

This started as a fork of [Ghostty](https://github.com/ghostty-org/ghostty) where we wanted to add smooth pixel scrolling. Then we added spring-animated cursors. Then a full Neovim GUI renderer. Then collab cursors, shader VFX, SDF rounded windows, a panel system, and block-art banners with GPU glow effects.

It's no longer a "fork with smooth scrolling." It's a GPU-native terminal that doubles as a Neovim IDE with visual effects you won't find anywhere else.

**100% of this exists because Ghostty exists.** Ghostty's terminal engine, GPU renderer, and architecture made all of this possible. We just wanted to see how far we could push it as a fun project.

### How is this different from...

- **Ghostty** -- Ghostty is a fast, correct, minimal terminal. This is a fast, correct, _maximal_ terminal. Ghostty is the foundation. We added everything on top.
- **Neovide** -- Neovide is a standalone Neovim GUI. This is a terminal that _contains_ a Neovim GUI. You get Neovide-style animations (smooth scroll, stretchy cursor, sonicboom VFX) without leaving your terminal. Your shell, your TUI apps, and your Neovim all live in one window.
- **Kitty / Wezterm / Alacritty** -- GPU terminals that render cells fast. They don't know what a "Neovim window" is. This does. The GPU renderer understands Neovim's multigrid protocol and applies per-window effects.

---

## Features

### Terminal Mode

Your normal shell, but smoother.

- **Pixel-perfect scrolling** -- Sub-line scroll tracking. Viewport moves by actual pixels, not whole lines. Text stays crisp on integer boundaries.
- **Spring-animated everything** -- Scroll and cursor movement use critically damped springs (same physics as Neovide). Configurable duration and bounciness.
- **Matte/ink post-processing** -- Subtle desaturation, shadow lift, and cool-tinted shadows for a refined look. Makes any colorscheme feel premium.
- **Text gamma and contrast** -- Fine-tune glyph weight and edge sharpness.

### Neovim GUI Mode

Type `nvim-gui` in the terminal. The session transforms into a native Neovim GUI renderer.

- **Per-window scroll springs** -- Each Neovim window animates independently. Statusline, winbar, and cmdline stay fixed while content scrolls.
- **Neovide-style cursor** -- 4-corner stretchy cursor with spring physics. Sonicboom VFX ring on mode changes (normal/insert/visual).
- **SDF rounded windows** -- Anti-aliased rounded corners on every Neovim window, rendered with signed distance fields on the GPU.
- **Floating window rendering** -- Z-order, clipping, opacity springs, position springs for smooth layout transitions.
- **Banner VFX** -- `:GhosttyBanner HELLO` inserts block-art ASCII headings with GPU-rendered animated color waves, bloom, sparkle particles, and edge glow. Colors adapt to your theme.
- **Image preview** -- Inline image rendering in the buffer.
- **All your plugins work** -- It's just Neovim. Your config, your plugins, your keybinds. Nothing changes.

### Collab Presence

Real-time collaborative cursors between multiple Ghostty instances, all local, just add a name, and a curor color.

### Panel GUI

Slide-out panels that run alongside your terminal (lazygit, htop, file explorer, etc). The terminal grid shrinks to make room -- split, not overlay. Spring-animated open/close.

---

## Quick Start

Add to `~/.config/ghostty/config`:

```
# Recommended defaults (these are already on)
pixel-scroll = true
collab-name = NAME
collab-color = #7aa2f7

```

For Neovim GUI mode, just type `nvim-gui` in the terminal. No config needed.

---

## Install

### Nix / NixOS (recommended)

Install directly from the flake:

```bash
nix profile install github:parkers0405/ghostty-pixel-scroll#ghostty-pixel-scroll
```

For NixOS binary downloads (no local build), configure Cachix:

```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "https://ghostty-pixel-scroll.cachix.org"
  ];
  trusted-public-keys = [
    "ghostty-pixel-scroll.cachix.org-1:vkWtQpi2OeQk5pzrpOAEF+FHm6b6PjKoypJBbYiZMuU="
  ];
};
```

### Flatpak (Linux)

```bash
flatpak remote-add --if-not-exists --no-gpg-verify ghostty-pixel-scroll \
  https://parkers0405.github.io/ghostty-pixel-scroll/flatpak-repo/ghostty-pixel-scroll.flatpakrepo

flatpak install ghostty-pixel-scroll com.mitchellh.ghostty//stable
```

Nightly channel:

```bash
flatpak install ghostty-pixel-scroll com.mitchellh.ghostty//tip
```

Update:

```bash
flatpak update
```

### Linux Tarball

Download `ghostty-linux-x86_64.tar.gz` from Releases, extract it, and run:

```bash
tar -xzf ghostty-linux-x86_64.tar.gz
./bin/ghostty
```

### macOS

Download `ghostty-macos-arm64-unsigned.zip` from Releases, unzip it, and open `Ghostty.app`.

### Source Build

If you want to build locally, use the Building section below.

---

## Building

**With Nix (recommended):**

```bash
nix-shell --run "zig build -Doptimize=ReleaseFast"
```

**Without Nix:**

Requires Zig 0.15+ and GTK4/libadwaita (same deps as Ghostty). See Ghostty's [build docs](https://ghostty.org/docs/install/build), then:

```bash
zig build -Doptimize=ReleaseFast
```

Binary: `zig-out/bin/ghostty`

```bash
./zig-out/bin/ghostty
```

---

## Releases (No Build)

Prebuilt release artifacts are published on the GitHub Releases page for tagged versions.

- `ghostty-linux-x86_64.tar.gz` for Linux.
- `ghostty-macos-arm64-unsigned.zip` for macOS (Apple Silicon).
- `ghostty-source.tar.gz` for downstream packaging.

NixOS users can avoid local builds if a Cachix binary cache is configured for this repo's release workflow.
Linux users can also install/update via Flatpak channels configured by the release workflow.

Every push to `main` can publish a nightly prerelease build via GitHub Actions.

---

## Configuration

### Animation & Scrolling

| Option                        | Default | Description                                                                    |
| ----------------------------- | ------- | ------------------------------------------------------------------------------ |
| `pixel-scroll`                | `true`  | Sub-line pixel scrolling for trackpads/mice.                                   |
| `scroll-animation-duration`   | `0.15`  | Scroll spring duration in seconds. 0 = instant. GUI mode auto-defaults to 0.3. |
| `scroll-animation-bounciness` | `0.0`   | Scroll spring overshoot (0.0-1.0).                                             |
| `cursor-animation-duration`   | `0.06`  | Cursor spring duration in seconds. 0 = instant teleport.                       |
| `cursor-animation-bounciness` | `0.0`   | Cursor spring overshoot (0.0-1.0).                                             |
| `invert-touchpad-scroll`      | `false` | Invert touchpad scroll direction.                                              |

### Visual

| Option            | Default | Description                                           |
| ----------------- | ------- | ----------------------------------------------------- |
| `matte-rendering` | `0.0`   | Ink post-processing intensity (0.0-1.0). Try 0.5.     |
| `text-gamma`      | `0.0`   | Glyph weight. Positive = thicker, negative = thinner. |
| `text-contrast`   | `0.0`   | Glyph edge sharpness.                                 |

### Neovim GUI

| Option                   | Default    | Description                                                                  |
| ------------------------ | ---------- | ---------------------------------------------------------------------------- |
| `neovim-gui`             | `""`       | Set to `spawn`, `embed`, or a socket path. Empty = normal terminal.          |
| `neovim-gui-config-mode` | `managed`  | `auto`, `user`, or `managed` profile mode for `nvim-gui` sessions.          |
| `neovim-gui-alias`       | `nvim-gui` | Shell function name for entering GUI mode via OSC 1338.                      |
| `neovim-corner-radius`   | `25.0`     | SDF rounded corner radius in pixels for Neovim windows. 0 = sharp corners.  |
| `neovim-gap-color`       | `#0a0a0a`  | Color between rounded windows (auto-syncs to Neovim bg color).              |
| `neovim-window-padding`  | `4.0`      | Gap in pixels between Neovim split windows. Makes rounded corners visible.   |

> **You don't need `neovim-gui` in your config.** Just type `nvim-gui` in the terminal. It sends an OSC escape sequence to switch modes on the fly. Only set `neovim-gui = spawn` if you want it to always launch as a Neovim GUI.

`neovim-gui-config-mode = managed` is the default. Ghostty seeds a managed NvChad profile at `~/.config/ghostty/nvim` on first run and launches that profile. Set `neovim-gui-config-mode = user` to always use `~/.config/nvim`, or `auto` to prefer user config only when it exists.

### Collaboration

| Option         | Default   | Description                                                           |
| -------------- | --------- | --------------------------------------------------------------------- |
| `collab-name`  | `""`      | Display name for collab sessions. Defaults to system username if empty. |
| `collab-color` | `#7aa2f7` | Your cursor color in collab sessions. Other participants see this.     |

### Panel GUI

| Option           | Default | Description                                                                              |
| ---------------- | ------- | ---------------------------------------------------------------------------------------- |
| `panel-gui-1`    | `""`    | Panel slot 1. Format: `position:module` (e.g. `right:lazygit`, `bottom:htop`).           |
| `panel-gui-2`    | `""`    | Panel slot 2. Same format.                                                               |
| `panel-gui-size` | `0.35`  | Panel size as fraction of surface (0.0-1.0).                                             |

**Default keybinds:** `Ctrl+/` (Linux) / `Cmd+/` (macOS) toggles the menu panel. Custom keybinds:

```
keybind = ctrl+shift+g=toggle_panel:lazygit
keybind = ctrl+shift+p=toggle_panel:panel
```

---

## How It Works

**Terminal pixel scrolling:** The renderer loads one extra row above the viewport. As you scroll, a sub-line pixel offset shifts the entire grid. When the offset crosses a cell height, the viewport advances one line and the offset wraps. Both the background fragment shader and text vertex shader receive the same `pixel_scroll_offset_y` uniform, rounded to whole pixels so text stays crisp.

**Spring animation:** All scroll and cursor movement feeds into critically damped springs. The spring position decays toward zero each frame. Fractional position maps to pixel offsets. The cursor uses 4 independent corner springs for the Neovide-style stretch/squash effect.

**Neovim GUI rendering:** Neovim's multigrid UI protocol sends per-window grid data. Each window gets its own scroll spring. The shader applies per-cell Y offsets only within scroll regions -- statuslines stay fixed. Floating windows have z-order, clipping, and position/opacity springs.

**Idle cost:** Kinda Zero. The animation timer only ticks while springs are active. Once everything settles, the renderer returns to event-driven drawing.

---

## Platform Support

Tested on **Linux (OpenGL)**. macOS Metal shaders are bit tested but could have issues.

## Known Issues

- Linux animation timer hardcoded to ~165hz (needs auto-detection)
- macOS Metal shaders not fully tested
- single line scrolling (ex: spamming jjjjj) not as smooth as it could be

---

## Credits

This project is built on [Ghostty](https://github.com/ghostty-org/ghostty) by [Mitchell Hashimoto](https://github.com/mitchellh). Ghostty's terminal emulation, GPU renderer, font system, and platform integration are the foundation everything here is built on. Licensed under MIT.

The Neovim GUI mode is inspired by [Neovide](https://github.com/neovide/neovide) -- we loved the smooth scrolling and animated cursor but wanted it inside a real terminal.
