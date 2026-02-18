# Releasing

This repository now includes a fork-friendly release workflow:

- Workflow: `.github/workflows/release-community.yml`
- Triggers:
  - Push a tag like `v0.1.0`
  - Push to `main` (nightly prerelease)
  - Manual run via `workflow_dispatch`

## What It Publishes

Each release publishes these GitHub release assets:

- `ghostty-source.tar.gz`
- `ghostty-linux-x86_64.tar.gz`
- `ghostty-macos-arm64-unsigned.zip`
- `com.mitchellh.ghostty-<branch>-x86_64.flatpak`
- `SHA256SUMS`

Notes:

- Linux archive is built on Ubuntu with GTK/libadwaita development packages.
- macOS archive is currently unsigned/notarized.
- Flatpak repo is published to GitHub Pages under `flatpak-repo`.

## Optional Nix Binary Cache (NixOS no-build path)

The workflow can also push `.#ghostty-releasefast` to Cachix.

Set these repository secrets to enable that job:

- `CACHIX_CACHE_NAME`
- `CACHIX_AUTH_TOKEN`

If secrets are not set, the Cachix job is skipped and release assets are still published.

For binary substitution on user machines, add your cache and public key to Nix settings
(NixOS `nix.settings` or user-level `nix.conf`):

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

When cache is configured, users can install by flake package name:

```bash
nix profile install github:parkersettle/ghostty-pixel-scroll#ghostty-pixel-scroll
```

For NixOS configuration, use:

```nix
environment.systemPackages = [
  inputs.ghostty-pixel-scroll.packages.${pkgs.system}."ghostty-pixel-scroll"
];
```

## Flatpak Remote Publish (terminal updates via `flatpak update`)

The workflow publishes a Flatpak OSTree repo to GitHub Pages.
Enable GitHub Pages in repo settings, source branch `gh-pages`.

Remote file URL:

```text
https://<owner>.github.io/<repo>/flatpak-repo/ghostty-pixel-scroll.flatpakrepo
```

Install stable:

```bash
flatpak remote-add --if-not-exists --no-gpg-verify ghostty-pixel-scroll \
  https://<owner>.github.io/<repo>/flatpak-repo/ghostty-pixel-scroll.flatpakrepo
flatpak install ghostty-pixel-scroll com.mitchellh.ghostty//stable
```

Install nightly:

```bash
flatpak install ghostty-pixel-scroll com.mitchellh.ghostty//tip
```

Update:

```bash
flatpak update
```

Note:

- The generated Flatpak repo is unsigned by default (`--no-gpg-verify` in install command).

## How To Cut A Release

Tag-based release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Manual release:

1. Open Actions -> `Release Community`
2. Click `Run workflow`
3. Set `tag` as `vX.Y.Z`
4. Choose `prerelease` if needed

## User Update Behavior

- Linux/macOS asset users: download the new release asset each version.
- NixOS users:
  - With your Cachix cache configured: updates pull binaries.
  - Without cache configured: `nix` builds locally from source.
- Flatpak users: `flatpak update`.

## Future Improvements

- Add signed + notarized macOS release artifacts.
- Add GPG signing for Flatpak repo metadata.
- Add Linux arm64 release artifacts.
