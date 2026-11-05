{ config, pkgs, ... }:

let
  # jetbrains.rider's own build hook (sharedLibsHook) resolves libstdc++.so.6
  # for several bundled native binaries (Rider.Backend, the debugger worker,
  # dotTrace, clang-format, etc.) to a path inside the *ephemeral build
  # sandbox* (/build/.../plugins/remote-dev-server/selfcontained/lib) and
  # bakes that into RPATH, so it no longer exists once the build finishes -
  # the backend then fails with "libstdc++.so.6: cannot open shared object
  # file". An LD_LIBRARY_PATH wrapper around bin/rider does NOT fix this:
  # Rider's frontend spawns Rider.Backend itself with its own environment,
  # not one inherited from the launcher script. The real fix has to patch
  # the RPATH baked into each affected binary directly, after nixpkgs' own
  # patching runs (hence postFixup, not postInstall). Same root cause as the
  # still-open https://github.com/NixOS/nixpkgs/issues/179454 (LLDBFrontend).
  rider = pkgs.jetbrains.rider.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.patchelf ];
    postFixup = (old.postFixup or "") + ''
      while IFS= read -r -d "" f; do
        if patchelf --print-needed "$f" 2>/dev/null | grep -qx 'libstdc++.so.6'; then
          patchelf --add-rpath ${pkgs.stdenv.cc.cc.lib}/lib "$f"
        fi
      done < <(find "$out" -type f -perm -u+x -print0)
    '';
  });
in
{
  home.username = "david";
  home.homeDirectory = "/home/david";

  dconf.settings = {
    # "org/gnome/desktop/background" = {
    #     picture-uri-dark = "file://${pkgs.nixos-artwork.wallpapers.nineish-dark-gray.src}";
    # };
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  gtk = {
    enable = true;
    gtk4.theme = null;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

  programs.zsh = {
    enable = true;

    history = {
      append = true;
    };

    shellAliases = {
      nrs = "sudo nixos-rebuild switch --flake ~/flakes";
      nrd = "sudo nixos-rebuild dry-run --flake ~/flakes";
      cat = "bat";
    };
  };

  programs.vim = {
    enable = true;
    extraConfig = ''
      set tabstop=4
      set shiftwidth=0
      set expandtab
      set autoindent
      inoremap jk <Esc>
    '';
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "David Muir";
        email = "hey@davidmuir.co";
      };
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

  programs.vscode = {
    enable = true;

    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        # Personal

        esbenp.prettier-vscode
        bbenoist.nix
        astro-build.astro-vscode
        vadimcn.vscode-lldb
        gleam.gleam
        hashicorp.terraform
        redhat.vscode-yaml
        rust-lang.rust-analyzer
      ];

      userSettings = {
        "workbench.sideBar.location" = "left";
        "explorer.confirmDragAndDrop" = false;
        "explorer.confirmDelete" = false;
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
        "editor.formatOnSave" = true;
        "rust-analyzer.checkOnSave" = true;
        "[rust].editor.defaultFormatter" = "rust-lang.rust-analyzer";
        "typescript.updateImportsOnFileMove.enabled" = true;
        "editor.inlineSuggest.enabled" = true;
        "editor.renderWhitespace" = "all";
        "rust-analyzer.check.command" = "clippy";
      };
    };
  };

  programs.alacritty = {
    enable = true;
    theme = "catppuccin_mocha";
  };

  programs.firefox = {
    enable = true;

    policies = {
      AppAutoUpdate = false;
      BlockAboutAddons = false;
      BlockAboutConfig = true;
      DefaultDownloadDirectory = "\${home}/Downloads";
      DisablePocket = true;
      DontCheckDefaultBrowser = true;
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          default_area = "menupanel";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
          private_browsing = true;
        };
        "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
          default_area = "menupanel";
          install_uri = "https://addons.mozilla.org/firefox/downloads/file/4692796/1password_x_password_manager-8.12.2.38.xpi";
          installation_mode = "force_installed";
          private_browsing = true;
        };
      };
      OfferToSaveLogins = false;
      SkipTermsOfUse = true;
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };
    };
  };

  programs.obsidian = {
    enable = true;
  };

  programs.zed-editor = {
    enable = true;
    userKeymaps = [
      {
        context = "Editor && vim_mode == insert";
        bindings = {
          "j k" = "vim::NormalBefore";
        };
      }
    ];
    userSettings = {
      vim_mode = false;
      base_keymap = "VSCode";
      show_whitespaces = "all";
      show_edit_predictions = true;
      ui_font_size = 16;
      buffer_font_size = 14;
      theme = {
        mode = "system";
        light = "One Light";
        dark = "One Dark";
      };
    };
  };

  home.packages = with pkgs; [
    rider
    bat
    rustup
    gcc
  ];

  home.stateVersion = "25.11";
}
