# Provisioning a new machine

This is only needed for the initial deployment. Subsequent modifications to the
configuration can be deployed more easily.

This assumes that a Linux (eg. Ubuntu) machine is running already, and that you
have SSH access to that machine with sudo priviledges. These steps will destroy
everything that existed on the machine, so make sure it wasn't being used for
anything important.

The deployment works by downloading a minimal NixOS installer image onto the
machine, using kexec to switch control from the currently running system into
the installer, and then finally running the installer. The installer image
runs entirely in memory, allowing it to reformat the disks as configured. This
process is automated thanks to the [nixos-anywhere][nixos-anywhere] tool.

[nixos-anywhere]: https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md

The instructions below use `<username>`, `<hostname>` and `<fqdn>` as
placeholders:
- `<username>` is a user on the existing system that has elevated priviledges,
    and for which you have SSH access. This would typically be `root` or
    `vagrant`.
- `<hostname>` should be the target machine's short hostname, eg. `wpia-packit`.
- `<fqdn>` is the full DNS name for the machine, eg. `wpia-packit.dide.ic.ac.uk`.

## Hardware configuration

> [!NOTE]
> If deploying to a new machine that is similar to an existing one (eg.
> deploying to a second Hyper-V VM), this step can be skipped. Instead use the
> existing `hardware-configuration.nix` file from the other machine's
> configuration. In doubt, you can also generate the configuration and compare it
> against an existing one.

The `hardware-configuration.nix` file is used to describe the machine's
hardware and configure any necessary extra kernel modules. It is generated
automatically by running the `nixos-generate-config` command on the target
machine itself.

The nixos-anywhere tool can be used to automate the process: the following
command will connect to the machine, use `kexec` to reboot into the installer,
runs `nixos-generate-config` and saves the result on your local machine to
`path/to/hardware-configuration.nix`.

```sh
nix run github:nix-community/nixos-anywhere -- --flake ".#<hostname>" \
  --phases "kexec" \
  --generate-hardware-config nixos-generate-config path/to/hardware-configuration.nix \
  <username>@<fqdn>
```

> [!NOTE]
> After nixos-anywhere has run for the first time, the machine will be running
> the NixOS installer and the `<username>` that was initially used will not
> exist anymore. For subsequent steps, use `root` as the username instead.

## Preparing the configuration

In `machines/default.nix` add a new entry under
`nixosConfigurations.<hostname>` which will be the system configuration. For
the initial provisioning, it is wise to start with a minimal configuration, and
then expand it progressively following the day-to-day deployment process.

The bare minimum configuration should look like:
```nix
{
  imports = [
    ./common/hardware-configuration.nix
    ./common/disk-config.nix
    ./common/base.nix
  ];
  networking.hostName = "<hostname>";
}
```

- The `hardware-configuration.nix` file should be the file generated earlier, or
  one re-used from a similar machine.
- The `disk-config.nix` file describes how the disk should be partitioned. The
  existing configuration is likely to be suitable.
- The `base.nix` file includes the basic configuration options needed, including
  enabling the SSH server, opening the firewall for it and configuring SSH keys.

## Running the installer

```sh
nix run github:nix-community/nixos-anywhere -- --flake ".#<hostname>" <username>@<fqdn>
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
    nix run .#deploy <hostname>
    ```

3. The machine is able to reboot and start correctly.

    ```sh
    ssh root@<fqdn> reboot
    ```

4. You can ssh again after the machine rebooted

    ```sh
    ssh root@<fqdn>
    ```

# Creating a new OAuth Application

Packit needs a GitHub OAuth application to function. Each application can only
be used with a single domain name. If deploying Packit to a new domain, a new
application will need to be created for it.

1. Go to https://github.com/organizations/reside-ic/settings/applications and click "New OAuth app".
2. Fill in the form, using `https://<domain>` (eg.
   `https://packit.dide.ic.ac.uk`) as both the "Homepage URL" and the
   "Authentication callback URL". Tick the "Enable Device Flow" box.
3. Click "Register Application"
4. Copy the Client ID
5. Generate and copy a client secret
6. Click "Update Application"
7. Store the two values in the Vault at a suitable location (eg.
   `packit/oauth/production`), with fields `clientId` and `clientSecret`.
8. Make sure the application is owned by `reside-ic`, not your own personal
   account. If needed, transfer ownership of it to `reside-ic`.

# Pulling secrets onto the server

After ssh-ing onto the server, the command `fetch-secrets` will pull all secrets
from Vault and store them under `/var/secrets`.

You will be prompted for GitHub personal access token in order to authenticate
against Vault.  The token is only used for the duration of this script. Neither
your GitHub PAT nor the Vault token that is obtained is persisted on the server.

TODO: consider using AppRole? Doesn't help with initial bootstrapping, but at
least we can add secrets without manual intervention.
