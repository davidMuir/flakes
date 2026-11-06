{ config, pkgs, inputs, ... }:

let
  # k3s comes from its own nixpkgs-k3s input, so it can be upgraded without moving the rest of
  # the node off its pinned nixpkgs, or moving the other hosts. Bump one minor version at a time
  # (see the cluster README in ~/src/k8s).
  k3sPkgs = inputs.nixpkgs-k3s.legacyPackages.x86_64-linux;
in
{
  imports =
    [
      ./hardware-configuration.nix
    ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  networking.hostName = "k8s-node-1";
  networking.networkmanager.enable = true;
  # 6443: k3s API.
  # 8097: Music Assistant audio streams (hostNetwork pod); players like Chromecasts fetch from it.
  networking.firewall.allowedTCPPorts = [ 6443 8097 ];
  # 5353: mDNS replies, so Music Assistant can discover players.
  networking.firewall.allowedUDPPorts = [ 5353 ];

  time.timeZone = "Europe/London";

  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  services.xserver.xkb = {
    layout = "gb";
    variant = "";
  };

  console.keyMap = "uk";

  users.users.david = {
    isNormalUser = true;
    description = "David Muir";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ6nzFo+z9m8A6pzc4QLkdivW0KPwDV1G7vsMa+Ngsb7"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  programs._1password.enable = true;

  services.openssh.enable = true;

  services.k3s = {
    enable = true;
    package = k3sPkgs.k3s_1_36;
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Lets `nixos-rebuild --target-host k8s-node-1` copy locally built paths here. david already
  # has sudo, so this doesn't grant anything new.
  nix.settings.trusted-users = [ "david" ];

  system.stateVersion = "25.11";

}
