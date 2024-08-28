{ pkgs, lib, config, localhost, ... }:
{
  virtualisation.vmVariant = {
    virtualisation.memorySize = 2048;
    virtualisation.forwardPorts = [{
      from = "host";
      host.port = 8443;
      guest.port = 443;
    }];
  };

  services.multi-packit = {
    domain = lib.mkForce "localhost";
    authenticationMethod = lib.mkForce "basic";
    corsAllowedOrigins = lib.mkForce "https://localhost:8443";
  };

  systemd.services."generate-secrets" = {
    wantedBy = [
      "multi-user.target"
      "nginx.service"
    ];
    before = [ "nginx.service" ];

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
    '';
  };

  services.getty.autologinUser = "root";
}
