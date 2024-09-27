{ pkgs, lib, config, ... }:
{
  virtualisation.memorySize = 2048;
  virtualisation.forwardPorts = [{
    from = "host";
    host.port = 8443;
    guest.port = 443;
  }];
  virtualisation.qemu.options = [ "-nographic" ];

  services.multi-packit = {
    domain = lib.mkForce "localhost:8443";
  };

  users.motd = ''
    Use the 'Ctrl-A x' sequence or the `shutdown now` command to terminate the VM session.
  '';

  systemd.services."generate-secrets" =
    let
      packit-units = map (name: "packit-api-${name}.service") config.services.multi-packit.instances;
      fetch-vm-secrets = pkgs.writeShellApplication {
        name = "fetch-vm-secrets";
        runtimeInputs = [ pkgs.vault-bin ];
        text = builtins.readFile ./scripts/fetch-vm-secrets.sh;
      };
    in
    {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      wantedBy = [ "multi-user.target" "nginx.service" ] ++ packit-units;
      before = [ "nginx.service" ] ++ packit-units;

      serviceConfig.Type = "oneshot";

      script = ''
        mkdir -p /var/secrets
        if [[ ! -f /var/secrets/packit.key ]]; then
          ${pkgs.openssl}/bin/openssl \
            req -x509 -days 365 \
            -subj "/CN=localhost" \
            -newkey rsa:2048 -noenc \
            -keyout /var/secrets/packit.key -out /var/secrets/packit.cert
          chown nginx:nginx /var/secrets/packit.key
        fi

        if [[ -f /sys/firmware/qemu_fw_cfg/by_name/opt/vault-token/raw ]]; then
          ${fetch-vm-secrets}/bin/fetch-vm-secrets
        fi
      '';
    };

  services.getty.autologinUser = "root";
}
