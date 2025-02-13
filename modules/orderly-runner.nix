{ self, pkgs, config, lib, ... }:
let
  inherit (lib) types;
  imageJson = lib.importJSON ../packages/orderly-runner/image.json;
  arrayFrom = n: if n == 1 then [ 1 ] else [ n ] ++ arrayFrom (n - 1);
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

  config.services.redis.servers.orderly-runner = {
    enable = true;
    port = 6379;
  };

  config.virtualisation.oci-containers.containers = {
    orderly-runner-api = rec {
      imageFile = pkgs.dockerTools.pullImage imageJson;
      image = "${imageJson.finalImageName}:${imageFile.imageTag}";
      extraOptions = [ "--network=host" "--pull=never" ];
      environment = {
        REDIS_URL = "redis://localhost";
        ORDERLY_RUNNER_QUEUE_ID = "orderly.runner.queue";
      };
      entrypoint = "/usr/local/bin/orderly.runner.server";
      cmd = [ "/data" "--port=${builtins.toString config.services.orderly-runner.port}" ];
      serviceName = "orderly-runner-api";
      volumes = [ "logs-volume:/logs" ];
    };
  } // lib.mergeAttrsList (map (num:
    let name = "orderly-runner-worker-${builtins.toString num}";
    in {
      "${name}" = rec {
        imageFile = pkgs.dockerTools.pullImage imageJson;
        image = "${imageJson.finalImageName}:${imageFile.imageTag}";
        extraOptions = [ "--network=host" "--pull=never" ];
        environment = {
          REDIS_URL = "redis://localhost";
          ORDERLY_RUNNER_QUEUE_ID = "orderly.runner.queue";
        };
        entrypoint = "/usr/local/bin/orderly.runner.worker";
        cmd = [ "/data" ];
        serviceName = name;
        volumes = [ "logs-volume:/logs" ];
      };
    }) (arrayFrom config.services.orderly-runner.workers));
}
