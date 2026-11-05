{ config, pkgs, ... }:

let
  locale = "en_GB.UTF-8";

  # StateDirectory=gnome-remote-desktop on the unit below owns this directory.
  tlsCert = "/var/lib/gnome-remote-desktop/tls.crt";
  tlsKey = "/var/lib/gnome-remote-desktop/tls.key";
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "home-pc";

  networking.networkmanager.enable = true;

  time.timeZone = "Europe/London";

  i18n = {
    defaultLocale = locale;

    extraLocaleSettings = {
      LC_ADDRESS = locale;
      LC_IDENTIFICATION = locale;
      LC_MEASUREMENT = locale;
      LC_MONETARY = locale;
      LC_NAME = locale;
      LC_NUMERIC = locale;
      LC_PAPER = locale;
      LC_TELEPHONE = locale;
      LC_TIME = locale;
    };
  };

  hardware.graphics.enable = true;

  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    environmentVariables = {
      # Default context window (4096) is too small for agent harnesses
      # like Pi that paste in file contents and tool output.
      OLLAMA_CONTEXT_LENGTH = "32768";
      # RX 9060 XT is RDNA4 (gfx1201). If ROCm doesn't recognize it out of
      # the box, uncomment and override to the nearest supported ISA:
      # HSA_OVERRIDE_GFX_VERSION = "11.0.0";
    };
  };

  services.xserver.enable = true;

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # RDP in from the Windows box. This is GNOME "remote login": the
  # gnome-remote-desktop system daemon terminates the RDP connection and hands
  # it to GDM, so you get a brand new session rather than a mirror of whatever
  # is on the physical monitor. GNOME refuses remote login to a user who
  # already holds a local session, so log out at the machine first.
  #
  # Authentication is two-stage. The client first authenticates against a
  # *system-wide* RDP credential to reach the GDM greeter, then signs in there
  # with a normal user account. That first credential is a shared secret, so it
  # is deliberately not in this file - it lives in the daemon's own state at
  # /var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop/credentials.ini
  # (nothing in the store, which is world readable). Set it out of band with:
  #
  #   sudo -u gnome-remote-desktop env SHELL=/run/current-system/sw/bin/bash \
  #     grdctl --system rdp set-credentials <rdp-username>
  #
  # omitting the password so it is prompted for rather than kept in shell
  # history. Without it the daemon logs "Credentials are not set, denying
  # client" and refuses every connection. Check with
  # `sudo grdctl --system status --show-credentials`.
  services.gnome.gnome-remote-desktop.enable = true;

  # GDM suspends the machine after a few minutes of sitting at the greeter,
  # which is exactly the state a remote-login box idles in - it would put
  # itself to sleep before you ever got the chance to connect.
  services.displayManager.gdm.autoSuspend = false;

  networking.firewall.allowedTCPPorts = [ 3389 ];

  # Upstream expects `grdctl --system rdp enable` to wire the daemon up, but
  # that goes through systemd's EnableUnitFiles, which cannot work on NixOS
  # where /etc/systemd/system is a read-only store symlink. Pull the unit in
  # declaratively instead.
  systemd.services.gnome-remote-desktop.wantedBy = [ "graphical.target" ];

  # The handover service is what the GDM greeter's session runs to accept the
  # RDP connection from the system daemon, so remote login does nothing without
  # it. Upstream ships it as WantedBy=gnome-session.target, but NixOS does not
  # realise [Install] sections for *user* units pulled in via systemd.packages,
  # and it has no session D-Bus activation file to fall back on - so link it by
  # hand. asDropin keeps the packaged unit body rather than replacing it.
  systemd.user.services.gnome-remote-desktop-handover = {
    overrideStrategy = "asDropin";
    wantedBy = [ "gnome-session.target" ];
  };

  # The system daemon's whole configuration is this one keyfile, so write it
  # directly rather than driving `grdctl --system`. grdctl only reaches the
  # settings through a polkit action it claims via pkexec, which on NixOS needs
  # both the setuid wrapper on PATH and a $SHELL listed in /etc/shells (systemd
  # gives a system user nologin) - and it exits 0 when pkexec refuses it, so
  # failures are silent. None of that applies to a file. The trade-off is that
  # grdctl can no longer change *these* settings, since the file is now a
  # read-only store symlink; edit them here instead. Credentials are untouched
  # by this - they live in credentials.ini, not here, so set-credentials above
  # still works.
  environment.etc."gnome-remote-desktop/grd.conf".text = ''
    [RDP]
    enabled=true
    tls-cert=${tlsCert}
    tls-key=${tlsKey}
  '';

  # The RDP backend refuses to start without a TLS certificate and there is no
  # NixOS option for one, so self-sign on first boot. This has to happen at
  # runtime rather than in the store: everything in /nix/store is world
  # readable, which is no place for a private key.
  systemd.services.gnome-remote-desktop-tls = {
    description = "Provision TLS certificate for GNOME Remote Desktop";
    wantedBy = [ "gnome-remote-desktop.service" ];
    before = [ "gnome-remote-desktop.service" ];
    path = [ pkgs.openssl ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "gnome-remote-desktop";
      Group = "gnome-remote-desktop";
      StateDirectory = "gnome-remote-desktop";
      StateDirectoryMode = "0700";
    };
    script = ''
      if [ -s ${tlsCert} ] && [ -s ${tlsKey} ]; then
        exit 0
      fi

      openssl req -x509 -nodes -newkey rsa:4096 -days 3650 \
        -subj "/CN=${config.networking.hostName}" \
        -out ${tlsCert} -keyout ${tlsKey}
      chmod 600 ${tlsKey}
    '';
  };

  services.xserver.xkb = {
    layout = "gb";
    variant = "";
  };

  console.keyMap = "uk";

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    glib
    SDL2
    SDL2_image
    SDL2_mixer
    SDL2_ttf
    libjpeg
    libpng
    portmidi
    # X11 backend
    xorg.libX11
    xorg.libXext
    xorg.libXrandr
    xorg.libXcursor
    xorg.libXi
    xorg.libXfixes
    xorg.libXrender
    # Wayland backend
    wayland
    libxkbcommon
    # For getting PyTorch to work for LLM attempts
    stdenv.cc.cc.lib
    zlib
    openssl
    numactl # ROCm wheels want libnuma
    libdrm
    elfutils
  ];

  programs.zsh.enable = true;
  programs.steam.enable = true;

  programs._1password.enable = true;
  programs._1password-gui.enable = true;

  # Decrypted with this host's own age key, which isn't in git. On a fresh install, copy it from
  # 1Password to this path before the first rebuild: with mutableUsers = false, david has no
  # password until the secret below can be decrypted.
  sops = {
    defaultSopsFile = ../../secrets/home-pc.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
    age.sshKeyPaths = [ ];
    gnupg.sshKeyPaths = [ ];
    secrets.david-password.neededForUsers = true;
  };

  users.mutableUsers = false;

  users.users.david = {
    isNormalUser = true;
    description = "David";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "video"
      "render"
    ];
    hashedPasswordFile = config.sops.secrets.david-password.path;
    shell = pkgs.zsh;
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    zsh
    dotnet-sdk_10
    nodejs
    spotify
    nil
    nixd
    alacritty
    duckdb
    bruno
    docker
    blink-qt
    uv
    claude-code
    gleam
    beamPackages.erlang
    beamPackages.rebar3
    tree
    gimp
    fluxcd
    kubectl
    sops
    graphviz
    gh
  ];

  virtualisation.docker.enable = true;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.05";
}
