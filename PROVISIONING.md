# Provisioning a new machine

This is only needed for the initial deployment. Subsequent modifications to the
configuration can be deployed more easily.

This assumes that a Linux (eg. Ubuntu) machine is has been provisioned running
already, and that you have SSH access to that machine with sudo priviledges.

The deployment works by downloading a minimal NixOS installer image onto the
machine, using kexec to switch control from the currently running system into
the installer, and then finally running the installer. The installer image
runs entirely in memory, allowing it to reformat the disks as configured. This
process is automated thanks to the [nixos-anywhere][nixos-anywhere] tool.

[nixos-anywhere]: https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md

The instructions below use `<hostname>` and `<fqdn>` as placeholders.
`<hostname>` should be the target machine's short hostname, eg. `wpia-packit`,
whereas `<fqdn>` is the full DNS name for the machine, eg.
`packit.dide.ic.ac.uk.

## Hardware configuration

> [!NOTE]
> If deploying to a new machine that is similar to an existing one (eg.
> deploying to a second Hyper-V VM), this step can be skipped. Instead copy the
> `hardware-configuration.nix` file from the existing machine's configuration
> and into the new one.

The `hardware-configuration.nix` file is used to describe the machine's
hardware and configure any necessary extra kernel modules. It is generated
automatically using the `nixos-generate-config` tool.

Before the `nixos-generate-config` tool can be run, the machine must be booted
into its installer first. This is done by connecting to the machine over SSH
and running the following command:

```sh
curl -L https://github.com/nix-community/nixos-images/releases/download/nixos-24.05/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz | sudo tar -xzf- -C /root
sudo /root/kexec/run
```

On your local machine you can now use `nixos-generate-config` over SSH to
generate the configuration and pipe it into a file:

```sh
ssh root@<fqdn> nixos-generate-config --show-hardware-config --no-filesystems > path/to/hardware-configuration.nix
```

## Preparing the configuration

In `flake.nix` add a new entry under `nixosConfigurations.<hostname>` which will
be the system configuration. For the initial provisioning, it is wise to start
with a minimal configuration, and then expand it progressively following the
day-to-day deployment process.

Make sure the configuration includes the following:
1. The ssh server is enabled, by setting `services.openssh.enable = true`.
2. Your SSH public key is added to the root account, with the
   `users.users.root.openssh.authorizedKeys` option.
3. The hardware configuration, by importing the generated
    `hardware-configuration.nix`.
4. The disk configuration. The existing `disk-config.nix` file should suffice
    for most cases and can be imported into your configuration.

## Running the installer

```sh
nix run github:nix-community/nixos-anywhere -- --flake ".#<hostname>" root@<fqdn>
```

## Refreshing SSH known hosts

After the installer runs and the machine reboots, new SSH host keys will be
generated. Your SSH client will refuse to connect to the machine, due to the
keys not matching its `known_hosts` file.

You can remove the existing entries for the particular machine using the
following command:

```sh
ssh-keygen -R <fqdn>
```

## Post provisioning checks

1. You can ssh into the machine

    ```sh
    ssh root@<fqdn>
    ```

2. You can update the configuration:

    ```sh
    nixos-rebuild switch --flake ".#<hostname>" --target-host root@<fqdn>
    ```

# Creating a new OAuth token

1. Go to https://github.com/settings/developers
2. homepage: `https://packit.dide.ic.ac.uk`
   callback URL: `https://packit.dide.ic.ac.uk`
3. Click "Register Application"
4. Copy the Client ID
5. Generate and copy a client secret
6. Click "Update Application"
7. Store the secrets in Vault at `secret/packit/oauth/production`, with fields
   `clientId` and `clientSecret`.

# Pulling secrets onto the server

After ssh-ing onto the server, the command `fetch-secrets` will pull all secrets
from Vault and store them under `/var/secrets`.

You will be prompted for GitHub personal access token in order to authenticate
against Vault.  The token is only used for the duration of this script. Neither
your GitHub PAT nor the Vault token that is obtained is persisted on the server.

TODO: consider using AppRole? Doesn't help with initial bootstrapping, but at
least we can add secrets without manual intervention.
