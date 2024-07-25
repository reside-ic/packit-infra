{ pkgs, lib, config, localhost, ... }:
{
  services.multi-packit.domain = lib.mkForce "localhost";

  systemd.services."generate-secrets" = {
    wantedBy = [
      "multi-user.target"
      "nginx.service"
    ];
    before = [ "nginx.service" ];

    serviceConfig.Type = "oneshot";

    script = ''
      mkdir -p /var/secrets
      ${pkgs.openssl}/bin/openssl \
        req -x509 -days 365 \
        -subj "/CN=localhost" \
        -newkey rsa:2048 -noenc \
        -keyout /var/secrets/packit.key -out /var/secrets/packit.cert
      chown nginx:nginx /var/secrets/packit.key

      touch /var/secrets/oauth-priority-pathogens
      touch /var/secrets/oauth-reside
    '';
  };

  services.getty.autologinUser = "root";
}
