{ self', lib, pkgs, config, ... }:
let
  # We use Let's Encrypt to provision automatically certificates for nginx.
  #
  # To get the certificates we need to prove ownership of the domains in an
  # automated fashion. The easiest way to do this is by hosting a challenge
  # on an http server and have Let's Encrypt fetch that challenge and check its
  # contents.
  #
  # Unfortunately some of our machines are behind a firewall and are only
  # accessible from within the DIDE network. To prove ownership of these
  # domains, we have to use a DNS challenge instead. This requires us to
  # be able to programatically configure a TXT DNS record on
  # `_acme-challenge.<hostname>.dide.ic.ac.uk`. Our DNS entries are managed by
  # ICT, using "HDB" as their source of truth. ICT provides an API to add
  # entries for this exact purpose.
  #
  # To make things simpler, we use DNS challenges across the board, even on
  # machines that are exposed publicly.
  #
  # The bash script below is used to interact with the HDB API. The script is
  # called by Lego, the ACME client used by NixOS, when we need to publish the
  # TXT DNS record.
  #
  # See https://go-acme.github.io/lego/dns/exec/ for the input specification.
  #
  # ICT did provide us with a certbot plugin, but integrating certbot into NixOS
  # would have been more work than integrating the HDB API into Lego.
  hdb-acme = pkgs.writeShellApplication {
    name = "hdb-acme";
    text = ''
      # shellcheck source=/dev/null
      source "$HDB_ACME_CREDENTIALS_FILE"
      action="$1"

      # Lego passes a trailing dot in the FQDN, which the HDB API refuses to
      # accept. This line below is removes it, if present.
      fqdn="''${2%.}"
      value="$3"

      case $action in
        present) method="PUT" ;;
        cleanup) method="DELETE" ;;
        *) exit 1 ;;
      esac

      # For some reason, the HDB API requires the token to be wrapped in an
      # extra layer of quotes, which is why we have a `tojson` call here.
      jq --null-input --arg value "$value" '{ token: $value | tojson }' |
        curl --no-progress-meter --fail --output /dev/null \
          --request "$method" --json @- \
          --basic -u "$HDB_ACME_USERNAME:$HDB_ACME_PASSWORD" \
          "https://hdb.ic.ac.uk/api/acme/v0/$fqdn/auth_token"
    '';
    runtimeInputs = [ pkgs.jq pkgs.curl ];
  };

  usesACME = config.security.acme.certs != { };
in
{
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "reside@imperial.ac.uk";
      dnsProvider = "exec";
      environmentFile = pkgs.writeText "env" ''
        EXEC_PATH="${lib.getExe hdb-acme}"
        EXEC_PROPAGATION_TIMEOUT=210
        # ICT makes the _acme-challenge record a CNAME, and by default Lego
        # follows that CNAME and tries to update the underlying record. That's
        # not what we want, so this disables that.
        LEGO_DISABLE_CNAME_SUPPORT=true
      '';
      credentialFiles = {
        HDB_ACME_CREDENTIALS_FILE = "/var/secrets/hdb-acme/credentials";
      };
    };
  };

  # We only bother fetching the HDB credentials if we have any ACME
  # certificates.
  vault.secrets = lib.mkIf usesACME {
    "hdb-acme-credentials" = {
      format = "env";
      path = "/var/secrets/hdb-acme/credentials";
      key = "certbot-hdb/credentials";
      fields.HDB_ACME_USERNAME = "username";
      fields.HDB_ACME_PASSWORD = "password";
    };
  };

  # This can be handy for debugging
  environment.systemPackages = lib.mkIf usesACME [ hdb-acme ];
}
