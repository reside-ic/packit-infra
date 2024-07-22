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
