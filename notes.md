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

