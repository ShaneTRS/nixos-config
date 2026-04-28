![NixOS Flakes](https://img.shields.io/badge/NixOS-Flakes-496aaf?style=for-the-badge&logo=nixos)
&nbsp;&nbsp;
![Hosts](https://img.shields.io/github/directory-file-count/shanetrs/nixos-config/systems?style=for-the-badge&label=Hosts&color=6ab43b)![Modules](https://img.shields.io/github/directory-file-count/shanetrs/nixos-config/modules?style=for-the-badge&label=Modules&color=5c9ecb)![Pkgs](https://img.shields.io/github/directory-file-count/shanetrs/nixos-config/overlays%2Fshanetrs?style=for-the-badge&label=Pkgs&color=496aaf)
&nbsp;&nbsp;
![Checks](https://img.shields.io/github/actions/workflow/status/shanetrs/nixos-config/check.yml?style=for-the-badge&label=Checks)![Commits Pending](https://img.shields.io/github/commits-difference/shanetrs/nixos-config?base=main&head=testing&style=for-the-badge&label=Commits%20Pending&color=orange)

A tree-driven flake that implicitly imports and defines its modules, systems, and overlays.

- Custom activation scripts for generating, linking, and merging config files declaratively [<sup>1](https://github.com/ShaneTRS/nixos-config/blob/e32d90f4477f2db4ce83a9aea34d19e4dd33dee6/modules/tundra.nix#L384-L418)
- Natively supported secrets via the declarative file generation scripts [<sup>2](https://github.com/ShaneTRS/nixos-config/blob/e32d90f4477f2db4ce83a9aea34d19e4dd33dee6/overlays/lib.nix#L18-L53)
- Overlaid Nixpkgs exposed via `legacyPackages.x86_64-linux`, for running any patched packages
- Custom flake evaluation checks via `deepSeq` derivations [<sup>3](https://github.com/ShaneTRS/nixos-config/blob/e32d90f4477f2db4ce83a9aea34d19e4dd33dee6/overlays/lib.nix#L268-L280)

```
nixos-config
├── flake.nix
├── modules
│   ├── example.nix
│   └── other-example
│       └── nested.nix
├── overlays
│   ├── channels.nix
│   ├── community.nix
│   ├── shanetrs
│   │   ├── example.nix
│   │   └── other-example
│   │       └── default.nix
│   ├── hotfixes.nix
│   └── lib.nix
├── systems
│   └── example
│       ├── default.nix
│       └── hardware.nix
├── user
│   ├── configs<user>/<system>
│   │   └── example.md    
│   └── homes/<user>/<system>
│       └── example.md    
├── apps.nix
└── shells.nix
```

---
1. [`tundra.nix#L384-L418`](https://github.com/ShaneTRS/nixos-config/blob/e32d90f4477f2db4ce83a9aea34d19e4dd33dee6/modules/tundra.nix#L384-L418) &nbsp; 2. [`lib.nix#L18-L53`](https://github.com/ShaneTRS/nixos-config/blob/e32d90f4477f2db4ce83a9aea34d19e4dd33dee6/overlays/lib.nix#L18-L53) &nbsp; 3. [`lib.nix#L268-L280`](https://github.com/ShaneTRS/nixos-config/blob/e32d90f4477f2db4ce83a9aea34d19e4dd33dee6/overlays/lib.nix#L268-L280)