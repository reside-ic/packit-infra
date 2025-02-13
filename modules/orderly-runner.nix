{ self, pkgs, config, lib, ... }:
let
  inherit (lib) types;
  imageJson = lib.importJSON ../packages/orderly-runner/image.json;

  getOrderlyRunnerContainer = { name, cmdFlags, entrypoint }: {
    "${name}" = {
      imageFile = pkgs.dockerTools.pullImage imageJson;
      image = "${imageJson.finalImageName}:${imageJson.finalImageTag}";
      extraOptions = [ "--network=host" "--pull=never" ];
      environment = {
        REDIS_URL = "redis://localhost";
        ORDERLY_RUNNER_QUEUE_ID = "orderly.runner.queue";
      };
      entrypoint = entrypoint;
      cmd = [ "/data" ] ++ cmdFlags;
      serviceName = name;
      volumes = [ "logs-volume:/logs" ];
    };
  };
in
{
  options.services.orderly-runner = {
    enable = lib.mkEnableOption "Orderly runner API";
    workers = lib.mkOption {
      description = "Number of workers to spin up";
      type = types.int;
    };
    port = lib.mkOption {
      type = types.port;
      default = 8240;
    };
  };

  config = lib.mkIf config.services.orderly-runner.enable {
    services.redis.servers.orderly-runner = {
      enable = true;
      port = 6379;
    };

    virtualisation.oci-containers.containers =
      getOrderlyRunnerContainer {
        name = "orderly-runner-api";
        cmdFlags = [ "--port=${builtins.toString config.services.orderly-runner.port}" ];
        entrypoint = "/usr/local/bin/orderly.runner.server";
      } // lib.mergeAttrsList (lib.genList (num:
        getOrderlyRunnerContainer {
          name = "orderly-runner-worker-${builtins.toString num}";
          cmdFlags = [];
          entrypoint = "/usr/local/bin/orderly.runner.worker";
        }
      ) config.services.orderly-runner.workers);
  };
}
