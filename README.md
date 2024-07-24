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

## How do I deploy to the server?

```sh
nix run .#deploy
```

or equivalently

```sh
nixos-rebuild switch --flake .#wpia-packit \
    --target-host root@packit.dide.ic.ac.uk \
    --use-substitutes
```

The `--use-substitutes` flag allows the target machine to download packages
straight from the NixOS public binary cache instead of them being pushed from
your local machine. This is generally faster.

## How do I build the deployment?

```sh
nixos-rebuild build --flake .#wpia-packit
```

This is useful to check syntax and that everything builds, but you don't
typically need to do it.

## How do I inspect the configuration? 

```sh
nixos-rebuild repl --flake .#wpia-packit
```

## How do I start a local VM?

```sh
nix run .#start-vm
```

This starts a local VM running in QEMU. Handy to check everything works as
expected before deploying.

It will forward port 443 of the VM onto port 8443, meaning you may visit
https://localhost:8443/ once the VM has started.

Nginx is configured using a self-signed certificate, which will cause some
browser warnings.

## How do I run the integration tests?

```sh
nix flake check
```

## How do I add new SSH keys?

The keys are fetched from GitHub and committed into this repository as the `authorized_keys` files.
You can edit the `scripts/update-ssh-keys.sh` file to update the list of users.

Afterwards run the following to fetch the new keys:
```sh
nix run .#update-ssh-keys
```

## How do I update outpack_server or Packit?

TODO

## How do I update nixpkgs?

```
nix flake update
```

To switch to a new major version, you should edit the URL at the top of `flake.nix`.

## How do I provision a new machine?

Still a TODO. See `notes.md`.
