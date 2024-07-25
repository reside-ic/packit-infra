# packit.dide.ic.ac.uk

## Preliminaries

You need Nix installed on your local dev machine, with flakes enabled. If you
don't have Nix installed, you can use SSH onto the server and use it to run the
commands. Obviously this doesn't work for initial provisioning.

Some of the steps below require tools that might not be installed by default.
You can enter a shell that provides all of them using

```sh
nix develop
```

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

```
nix-prefetch-github --json mrc-ide outpack_server > packages/outpack_server/sources.json
nix-prefetch-github --json mrc-ide packit > packages/packit/sources.json
```

The `nix-prefetch-github` command also accepts a `--rev` argument which may be
used to specify a branch name.

If the project being updated has modified its dependencies, you will need to
update the associated hashes. For example, in
`packages/outpack_server/default.nix`, replace the `cargoHash` line with
`cargoHash = lib.fakeHash;`. Build the package and nix will fail and give the
expected hash to use. Similarly, `npmDepsHash` needs to be updated for Packit.

## How do I add a new Packit instance?

Edit `services.nix` by adding a new entry to the `services.multi-packit.instances`
attribute set. Choose a new pair of unused port numbers for the outpack server
and for the packit API server. A GitHub organization and team needs to be
specified. All members of this organisation will be allowed to access the
instance.

TODO: users need to be granted additional permissions manually.

## How do I update nixpkgs?

```
nix flake update
```

To switch to a new major version, you should edit the URL at the top of `flake.nix`.

## How do I provision a new machine?

Still a TODO. See `notes.md`.
