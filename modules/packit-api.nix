{ pkgs, self', config, lib, ... }:
let
  inherit (lib) types;

  policyModule = {
    options = {
      jwkSetUri = lib.mkOption {
        description = ''
          The URI from which the public key of the issuer is retrieved from.
          This forms the source of trust for service accounts.
        '';
        type = types.str;
      };
      issuer = lib.mkOption {
        description = ''
          The expected value of the `iss` claim for tokens matching this policy.
        '';
        type = types.str;
      };
      requiredClaims = lib.mkOption {
        description = ''
          The JWT claims required of tokens matching this policy. Only
          string-valued claims are supported.
        '';
        type = types.attrsOf types.str;
        default = { };
      };
      grantedPermissions = lib.mkOption {
        description = ''
          The permissions granted to service tokens that match this policy.
        '';
        type = types.listOf types.str;
        default = [ ];
      };
      tokenDuration = lib.mkOption {
        description = ''
          The lifespan of tokens issued under this policy. If omitted, service
          tokens' lifespan match the instance-wide configuration (typically 1
          day).
        '';
        type = types.nullOr types.str;
        default = null;
      };
    };
  };

  instanceModule = { name, config, ... }: {
    options = {
      enable = lib.mkEnableOption "the Packit API server";
      apiRoot = lib.mkOption {
        type = types.str;
      };
      port = lib.mkOption {
        default = 8080;
        type = types.port;
      };
      management-port = lib.mkOption {
        default = 8081;
        type = types.port;
      };
      outpackServerUrl = lib.mkOption {
        default = "http://127.0.0.1:8000";
        type = types.str;
      };

      database = {
        url = lib.mkOption {
          description = "URL to database";
          default = "jdbc:postgresql://127.0.0.1:5432/packit?stringtype=unspecified";
          type = types.str;
        };
        user = lib.mkOption {
          type = types.str;
        };
        password = lib.mkOption {
          type = types.str;
        };
      };

      authentication = {
        method = lib.mkOption {
          description = "Authentication method";
          type = types.enum [ "basic" "github" ];
        };
        github = {
          redirect_url = lib.mkOption {
            description = "URL to which to redirect following an authentication attempt";
            type = types.str;
          };
          org = lib.mkOption {
            description = "GitHub organisation used for authentication";
            type = types.str;
          };
          team = lib.mkOption {
            description = "GitHub team used for authentication";
            type = types.str;
            default = "";
          };
        };
        service = {
          audience = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          policies = lib.mkOption {
            type = types.listOf (lib.types.submodule policyModule);
            default = [ ];
          };
        };
      };

      corsAllowedOrigins = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
      };

      defaultRoles = lib.mkOption {
        description = "Default list of roles assigned to new users";
        type = types.listOf types.str;
        default = [ ];
      };
      environmentFiles = lib.mkOption {
        type = types.listOf types.path;
        default = [ ];
      };
      properties = lib.mkOption {
        description = "Additional application properties";
        type =
          let t = types.nullOr (types.oneOf [ types.str (types.listOf t) (types.attrsOf t) ] // { description = "Java property"; });
          in types.attrsOf t;
      };
    };

    config = {
      # The authentication.service configuration option is mapped straight onto properties.
      # Eventually, most / all of the configuration could be managed with this, instead of
      # using environment variables.
      properties.auth.service = config.authentication.service;
    };
  };

  # This maps the structured properties object into a flat map of strings.
  # A list `x` is converted to `x[0]`, `x[1]`, ...
  # A attribute set `x` is converted to `x.a`, `x.b`, ... where a and b are the keys of the attribute set.
  # A null value is omitted from the result.
  flattenProperties' = key: value:
    if lib.isString value then { "${key}" = value; }
    else if lib.isList value then lib.mergeAttrsList (lib.imap0 (i: el: flattenProperties' "${key}[${toString i}]" el) value)
    else if lib.isAttrs value then lib.concatMapAttrs (k: el: flattenProperties' "${key}.${k}" el) value
    else if value == null then { }
    else throw "bad type";
  flattenProperties = lib.concatMapAttrs flattenProperties';

  foreachInstance = f: lib.mkMerge (lib.mapAttrsToList f config.services.packit-api.instances);
in
{
  options.services.packit-api.instances = lib.mkOption {
    type = types.attrsOf (types.submodule instanceModule);
    default = { };
  };

  config.systemd.services = foreachInstance (name: instanceCfg: lib.mkIf instanceCfg.enable {
    "packit-api-${name}" = {
      description = "Packit API ${name}";
      wantedBy = [ "multi-user.target" ];
      wants = [ "postgresql.service" ];
      after = [ "postgresql.service" ];

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        ProtectSystem = true;

        # 143 exit code is standard Spring boot behaviour it seems.
        # https://docs.spring.io/spring-boot/3.3.0/how-to/deployment/installing.html#howto.deployment.installing.system-d
        SuccessExitStatus = "143";

        ExecStart =
          let arguments = lib.mapAttrsToList (k: v: "--${k}=${v}") (flattenProperties instanceCfg.properties); in
          lib.escapeShellArgs ([ "${self'.packages.packit-api}/bin/packit-api" ] ++ arguments);
        EnvironmentFile = instanceCfg.environmentFiles;
      };

      environment = {
        SERVER_PORT = toString instanceCfg.port;
        PACKIT_MANAGEMENT_PORT = toString instanceCfg.management-port;
        PACKIT_OUTPACK_SERVER_URL = instanceCfg.outpackServerUrl;
        PACKIT_DB_URL = instanceCfg.database.url;
        PACKIT_DB_USER = instanceCfg.database.user;
        PACKIT_DB_PASSWORD = instanceCfg.database.password;
        PACKIT_API_ROOT = instanceCfg.apiRoot;
        PACKIT_DEFAULT_ROLES = lib.concatStringsSep "," instanceCfg.defaultRoles;
        PACKIT_CORS_ALLOWED_ORIGINS = lib.concatStringsSep "," instanceCfg.corsAllowedOrigins;
        PACKIT_AUTH_METHOD = instanceCfg.authentication.method;
      } // (lib.optionalAttrs (instanceCfg.authentication.method == "github") {
        PACKIT_AUTH_REDIRECT_URL = instanceCfg.authentication.github.redirect_url;
        PACKIT_AUTH_GITHUB_ORG = instanceCfg.authentication.github.org;
        PACKIT_AUTH_GITHUB_TEAM = instanceCfg.authentication.github.team;
      });
    };
  });
}
