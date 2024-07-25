# Provisioning the VM

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

# Setting up SSL certificates

```
vault kv get -field=value /secret/packit/ssl/production/cert | ssh root@packit.dide.ic.ac.uk tee /var/secrets/packit.cert
vault kv get -field=value /secret/packit/ssl/production/key | ssh root@packit.dide.ic.ac.uk tee /var/secrets/packit.key
```

# Creating a new OAuth token

1. Go to https://github.com/settings/developers
2. homepage: `https://packit.dide.ic.ac.uk/priority-pathogens`
   callback URL: `https://packit.dide.ic.ac.uk/priority-pathogens/packit/api/login/oauth2/code/github`
3. Click "Register Application"
4. Copy the Client ID
5. Generate and copy a client secret
6. Click "Update Application"
7. Create a file `/var/secrets/github-oauth` on the server with:
```
PACKIT_GITHUB_CLIENT_ID=xxxx
PACKIT_GITHUB_CLIENT_SECRET=xxxx
```

These secrets are stored in Vault at `/secret/packit/oauth/production`.
