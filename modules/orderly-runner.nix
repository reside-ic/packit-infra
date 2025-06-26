{ self, pkgs, config, lib, ... }:
let
  inherit (lib) types;
  image = pkgs.dockerTools.pullImage (lib.importJSON ../packages/orderly-runner/image.json);

  REDIS_URL = "redis://localhost";
  ORDERLY_RUNNER_QUEUE_ID = "orderly.runner.queue";

  getOrderlyRunnerContainer = { name, cmdFlags, entrypoint }: {
    "${name}" = {
      image = "docker-archive:${image}";
      extraOptions = [ "--network=host" "--pull=never" ];
      environment = { inherit REDIS_URL ORDERLY_RUNNER_QUEUE_ID; };
      entrypoint = entrypoint;
      cmd = [ "/data" ] ++ cmdFlags;
      serviceName = name;
      volumes = [ "logs-volume:/logs" ];
    };
  };

  rprofile = pkgs.writeText ".Rprofile" ''
    library(rrq)
    rrq_default_controller_set(rrq_controller(Sys.getenv("ORDERLY_RUNNER_QUEUE_ID")))
  '';

  runner-cli = pkgs.writeShellScriptBin "runner-cli" ''
    exec "${lib.getExe config.virtualisation.podman.package}" run --network=host --pull=never \
      --volume "${rprofile}:/root/.Rprofile:ro" \
      --env "ORDERLY_RUNNER_QUEUE_ID=${ORDERLY_RUNNER_QUEUE_ID}" \
      --env "REDIS_URL=${REDIS_URL}" \
      --rm --tty --interactive \
      "docker-archive:${image}" R "$@"
  '';
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

    environment.systemPackages = [
      runner-cli
    ];
  };
}
