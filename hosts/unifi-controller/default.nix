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

  system.stateVersion = "25.05";

}