# packit.dide.ic.ac.uk

## Preliminaries

You need Nix installed on your local machine. You can use the
[DeterminateSystems installer](https://github.com/DeterminateSystems/nix-installer) for this:

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

## Standard operating procedures
- [Provisioning a new machine](playbooks/new-machine-provisioning.md)
- [Deploying a new instance](playbooks/new-packit-instance.md)
- [Wiping a Packit instance](playbooks/wipe-packit-instance.md)

## How do I?
### How do I deploy to the server?

```sh
nix run .#deploy <hostname>
```

Where `<hostname>` is replaced by `wpia-packit` or `wpia-packit-private`.

### How do I update outpack_server or Packit?

The Git revision of outpack_server and packit is pinned in JSON files found in
the [`packages/` directory](packages). These files also locks the packages'
dependencies.

A [GitHub actions workflow](.github/workflows/update.yaml) runs nightly and
creates (or updates) a pull request to update outpack_server and Packit to
their latest revision. If necessary, the workflow can also be triggered
manually, in which case an alternative branch may be specified.

After merging the pull request created by the workflow, you should re-deploy to
all hosts following the instructions above.

Equivalently, you may update the versions manually yourself by running either
of the following commands:

```
nix run .#update outpack_server
nix run .#update packit
```

### How do I build the deployment?

```sh
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

This is useful to check syntax and that everything builds, but you don't
typically need to do it. Deploying will do it implicitely.

### How do I visualize the effect of my changes?

```
nix run .#diff <hostname>
```

This will download the system that is currently running on the server and
compare it with what would be deployed using [nix-diff](https://github.com/Gabriella439/nix-diff).

Alternatively, when opening a pull request on GitHub an action will run and
compute the difference against the main branch for all machines, and post the
result as a comment.

### How do I start a local VM?

```sh
nix run .#start-vm <hostname>
```

This starts a local VM running in QEMU. Handy to check everything works as
expected before deploying.

Before starting the local VM, this command will obtain a Vault token and inject
it into the VM to be used for fetching GitHub client ID and secrets. If needed,
you may be prompted for your GitHub personal access token.

Port 443 of the VM is exposed as port 8443, meaning you may visit
https://localhost:8443/ once the VM has started. nginx is configured using a
self-signed certificate, which will cause some browser warnings.

Packit is configured to use GitHub authentication. If needed, after logging in,
you may grant yourself more permissions on a particular Packit instance through
the VM console.

```
grant-role <instance> <github username> ADMIN
```

### How do I run the integration tests?

```sh
nix run .#integration-test
nix run .#integration-test -- --interactive
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

### How do I add new SSH keys?

The keys are fetched from GitHub and committed into this repository as the
`authorized_keys` files. You can edit the `scripts/update-ssh-keys.sh` file to
update the list of users.

Afterwards run the following to fetch the new keys:
```sh
nix run .#update-ssh-keys
```

Carefully review the changes to avoid locking yourself out and re-deploy to the
server.

### How do I add secrets to a machine?

All secrets are fetched from Vault. To add a new secret to a machine, add it
to the Vault and add an entry to the `vault.secrets` option.

```nix
vault.secrets = [{
    key = "name/of/secret";
    path = "/var/secret/mysecret";
}];
```

After deploying the configuration to the machine, SSH onto it and run the
`fetch-secrets` command to pull all the secrets. You will be prompted for your
GitHub personal access token in order to authenticate against Vault.  The
token is only used for the duration of this script. Neither your GitHub PAT
nor the Vault token that is obtained is persisted on the server.

To debug the secrets configuration, you can also run the command locally by
running:

```sh
nix run .#nixosConfigurations.<hostname>.config.vault.tool -- --root here
```

This will fetch all the secrets as the command on the server would have done,
but store them relative to the `here` folder.

### How do I inspect / edit the database?

If doing this on the production instance, start by thinking very carefully
about what you are about to do.

From the VM console or an SSH session, you can use the `psql` tool to get an
SQL session to the database of your choice. Each Packit instance uses its own
database. The root Linux user has permissions to access any of them.

```sh
psql <instance>
=# SELECT * FROM "user";
```

The database is initially populated by the packit-api service. During the first
start of a new instance, it can take a minute for the service to start and for
the database's tables to exist.

### How do I update NixOS?

```sh
nix flake update
```

To switch to a new major version, you should edit the URL at the top of `flake.nix`.
