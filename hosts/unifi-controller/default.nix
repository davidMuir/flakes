{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "unifi-controller"; # Define your hostname.
  networking.firewall.allowedTCPPorts = [ 8443 8080 ];

  time.timeZone = "Etc/UTC";

  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "uk";

  environment.systemPackages = with pkgs; [
    vim
    wget
  ];

  services.openssh.enable = true;

  services.unifi = {
    enable = true;
    openFirewall = true;
  };
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  nixpkgs.config.allowUnfree = true;

  # No autoUpgrade here (yet). services.unifi uses mongodb 7.0, which is unfree and so isn't in
  # the binary cache: building it on this 2-vCPU/4 GB box would take hours. Build it on home-pc
  # and deploy with `nixos-rebuild --target-host` instead. Unattended upgrades could also move
  # MongoDB to a new major version, which it can't always start on. Hetzner backups are off, so
  # previous generations are the only rollback.

  system.stateVersion = "25.05";

}