{ pkgs, ... }:
{
  services.openssh.enable = true;

  services.outpack.instances.priority-pathogens = {
    enable = true;
  };

  services.packit-api = {
    image = "mrcide/packit-api:0dd3d4e";
    instances.priority-pathogens = {
      enable = true;
      api_root = "https://packit.dide.ic.ac.uk/priority-pathogens/packit/api";
      redirect_url = "https://packit.dide.ic.ac.uk/priority-pathogens/redirect";
      database.url = "jdbc:postgresql://127.0.0.1:5432/priority-pathogens?stringtype=unspecified";
      database.user = "priority-pathogens";
      database.password = "priority-pathogens";
      environmentFiles = [ "/var/secrets/oauth-priority-pathogens" ];
    };
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "priority-pathogens" ];
    enableTCPIP = true;
    authentication = ''
      host all      all     127.0.0.1/32   trust
      host al       all     ::1/128        trust
    '';
    ensureUsers = [{
      name = "priority-pathogens";
      ensureDBOwnership = true;
    }];
  };

  services.nginx = {
    enable = true;
    logError = "stderr debug";
    virtualHosts."packit.dide.ic.ac.uk" = {
      addSSL = true;
      sslCertificate = "/var/secrets/packit.cert";
      sslCertificateKey = "/var/secrets/packit.key";

      locations = {
        "= /priority-pathogens" = {
          return = "301 /priority-pathogens/";
        };

        "~ ^/priority-pathogens(?<path>/.*)$" = {
          root = pkgs.packit.override {
            PUBLIC_URL = "/priority-pathogens";
          };
          tryFiles = "$path /index.html =404";
        };

        "^~ /priority-pathogens/packit/api/" = {
          priority = 999;
          proxyPass = "http://127.0.0.1:8080/";
        };
      };
    };
  };
}
