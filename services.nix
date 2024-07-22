{ ... }:
{
  services.openssh.enable = true;

  services.outpack.instances.priority-pathogens = {
    enable = true;
  };
}
