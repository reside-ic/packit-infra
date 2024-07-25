# Provisioning the server
This is only needed for the initial deployment. Afterwards modifications to the
configuration can be deployed more easily.

- ssh into machine

```
curl -L https://github.com/nix-community/nixos-images/releases/download/nixos-24.05/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz | sudo tar -xzf- -C /root
sudo /root/kexec/run
```

- ssh into machine as root@
```
nixos-generate-config --no-filesystems --dir ~
```

- Pull `hardware-configuration.nix` from remote
```
scp root@packit.dide.ic.ac.uk:hardware-configuration.nix .
```

```
nix run github:nix-community/nixos-anywhere -- --flake .#wpia-packit root@packit.dide.ic.ac.uk
```

```
ssh-keygen -f '/home/pl2113/.ssh/known_hosts' -R 'packit.dide.ic.ac.uk'
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
