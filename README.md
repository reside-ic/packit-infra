# packit.dide.ic.ac.uk

## Preliminaries

You need Nix installed on your local machine. You can use the
[DeterminateSystems installer](https://github.com/DeterminateSystems/nix-installer) for this:

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

## How do I deploy to the server?

```sh
nix run .#deploy
```

TODO: doing builds locally and then uploading them is pretty inefficient.
There's almost certainly a way to do the build remotely and not have to transfer
anything.

## How do I update outpack_server or Packit?

```
nix run .#update packit
nix run .#update outpack_server
```

The sources are defined in files at `packages/{packit,outpack_server}/source.json`.
The update script automatically fetches the latest revision from GitHub, and
updates the necessary hashes.

It also accepts a `--branch` argument which may be used to specify a branch
name. Otherwise the default branch of the repository will be used (usually main
or master).

## How do I build the deployment?

```sh
nix build
```

This is useful to check syntax and that everything builds, but you don't
typically need to do it. Deploying will do it implicitely.

## How do I visualize the effect of my changes?

```
nix run .#diff
```

This will download the system that is currently running on the server and
compare it with what would be deployed using [nix-diff](https://github.com/Gabriella439/nix-diff).

`nix-diff` will omit derivations' environment comparison if some dependencies
already differ. `nix run .#diff -- --environment` can help print all of these,
but is likely to be very verbose.

## How do I start a local VM?

```sh
nix run .#start-vm
```

This starts a local VM running in QEMU. Handy to check everything works as
expected before deploying.

When starting, this command will obtain a Vault token and inject it into the VM
to be used for fetch GitHub client ID and secrets. If needed, you may be
prompted for your GitHub personal access token.

Port 443 of the VM is exposed as port 8443, meaning you may visit
https://localhost:8443/ once the VM has started. nginx is configured using a
self-signed certificate, which will cause some browser warnings.

Packit is configured to use GitHub authentication. If needed, after logging in,
you may grant yourself more permissions on a particular Packit instance through
the VM console.

```
grant-role <instance> <github username> ADMIN
```

## How do I run the integration tests?

```sh
nix run .#vm-test
nix run .#vm-test -- --interactive
```

The second command starts a Python session which may be used to interact with the test machine.

The full checks can be run using the following command:
```sh
nix flake check -L
```

Depending on your host system and how Nix was installed on it, this may fail
with a "qemu-kvm: failed to initialize kvm: Permission denied" error. This
typically means that `/dev/kvm` and is not writable by the Nix build users.

This can be fixed by changing the devices ACLs (Access Control Lists) to make it writable by all
members of the nixbld group:

```sh
sudo setfacl -m g:nixbld:rw /dev/kvm
```

The above command will probably not persist across reboots. For that to work,
create a udev rule using the following commands:

```sh
sudo tee /etc/udev/rules.d/50-nixbld-kvm.rules <<EOF
KERNEL=="kvm", RUN+="/bin/setfacl -m g:nixbld:rw $env{DEVNAME}"
EOF
sudo udevadm control --reload-rules && sudo udevadm trigger
```

## How do I add new SSH keys?

The keys are fetched from GitHub and committed into this repository as the
`authorized_keys` files. You can edit the `scripts/update-ssh-keys.sh` file to
update the list of users.

Afterwards run the following to fetch the new keys:
```sh
nix run .#update-ssh-keys
```

Carefully review the changes to avoid locking yourself out and re-deploy to the
server.

## How do I add a new Packit instance?

Edit `services.nix` by adding a new entry to the `services.multi-packit.instances`
list.

You will need to customize the instance by configuring some of the
`services.packit-api.<name>` options. A GitHub organisation and team needs to
be specified. All members of this organisation/team will be allowed to access
the instance. The team can be omitted or left blank, in which case any member
of the organisation will have access.

The Packit application on Github manually needs to be granted permission, by
one of the organisation's admins, to access the organisation. See [the GitHub
documentation][github-oauth-org]. Because we use a single OAuth app for all
instances, this only needs to be done once per org, even if uses by multiple
instances.

[github-oauth-org]: https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-personal-account-on-github/managing-your-membership-in-organizations/requesting-organization-approval-for-oauth-apps

The initial user needs to be granted the ADMIN role manually.

1. Log in to the instance with your GitHub account.
1. SSH onto the server.
1. Run `grant-role <instance> <username> ADMIN` where `<instance>` is the name
   of the instance and `<username>` is your GitHub username.
1. Log out and back in for the changes to take effect.

Afterwards permissions may be managed through the web UI.

## How do I update NixOS?

```
nix flake update
```

To switch to a new major version, you should edit the URL at the top of `flake.nix`.

## How do I provision a new machine?

See [`PROVISIONING.md`](PROVISIONING.md).
