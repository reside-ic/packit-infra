{ config, ... }: {
  services.comin = {
    enable = true;
    remotes = [{
      name = "origin";
      url = "https://github.com/reside-ic/packit-infra";

      branches.main.name = "deploy/${config.networking.hostName}";
      # We don't use testing branches - we manage test environments through
      # GitHub.
      branches.testing.name = "";
    }];
  };
}
