{ pkgs, ... }:
{
  networking.extraHosts = ''
    127.0.0.1 packit.dide.ic.ac.uk
  '';

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
        -subj "/CN=packit.dide.ic.ac.uk" \
        -newkey rsa:2048 -noenc \
        -keyout /var/secrets/packit.key -out /var/secrets/packit.cert
      chown nginx:nginx /var/secrets/packit.key

      touch /var/secrets/oauth-priority-pathogens
    '';
  };

  services.getty.autologinUser = "root";
}
