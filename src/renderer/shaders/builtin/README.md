# Built-in Shader Presets

These files are built into Ghostty and can be selected with:

```ini
custom-shader = builtin:crt-curved
```

Available presets:

- `crt-curved`
- `phosphor-green`
- `blue-neon-grid`
- `amber-console`
- `hud-diagnostic`

Disable shader effects:

```ini
custom-shader =
```

Live switching (current surface):

- OSC: `printf '\e]1345;crt-curved\a'`
- OSC disable: `printf '\e]1345;none\a'`
- Shell helpers (from Ghostty shell integration):
  - `ghostty-shaders`
  - `ghostty-shader crt-curved`
  - `ghostty-shader none`
- Neovim commands:
  - `:GhosttyShader <preset>`
  - `:GhosttyShaders`
