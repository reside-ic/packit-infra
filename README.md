# packit.dide.ic.ac.uk

## Preliminaries

You need Nix installed on your local dev machine, with flakes enabled. If you
don't have Nix installed, you can use SSH onto the server and use it to run the
commands. Obviously this doesn't work for initial provisioning.

You also need the `nixos-rebuild` tool. If running NixOS this should already by
available.  If you've install Nix on a non-NixOS machine, you can enter a shell
with the tool by using `nix shell nixpkgs#nixos-rebuild`.

TODO: add a `nix develop` to `flake.nix` that brings a shell with the right
tools available.

## How do I build the deployment?

```sh
nixos-rebuild build --flake .#wpia-packit
```

This is useful to check syntax and that everything builds, but you don't
typically need to do it.

## How do I deploy to the server?

```sh
nixos-rebuild switch --flake .#wpia-packit \
    --target-host root@packit.dide.ic.ac.uk \
    --use-substitutes
```

The `--use-substitutes` flag allows the target machine to download packages
straight from the NixOS public binary cache instead of them being pushed from
your local machine. This is generally faster.

## How do I inspect the configuration? 

```sh
nixos-rebuild repl --flake .#vm
```

This will start a local 

## How do I start a local VM?

```sh
nixos-rebuild build-vm --flake .#test-vm
./result/bin/run-wpia-packit-vm
```

This starts a local VM running in QEMU. Handy to check everything works as
expected before pushing. Nginx will still expect the hostname to be
`packit.dide.ic.ac.uk`, but uses a self-signed certificate.

A `/etc/hosts` entry is setup on the VM, meaning
`curl --insecure https://packit.dide.ic.ac.uk` should work.

TODO: how do you forward

## How do I run the integration tests?

```sh
nix flake check
```

## How do I update outpack_server or Packit?

TODO

## How do I update nixpkgs?

## How do I provision a new machine?

Still a TODO. See <notes.md>
