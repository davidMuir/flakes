{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    # k8s-node-1's OS is pinned to the nixpkgs it was deployed with. Its k3s comes from `nixpkgs`
    # instead, by explicit minor version (k3s_1_xx) in hosts/k8s-node-1, so `nix flake update` only
    # moves it to a newer patch release. See the cluster README in ~/src/k8s.
    nixpkgs-k8s-node-1.url = "github:nixos/nixpkgs/1306659b587dc277866c7b69eb97e5f07864d8c4";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # Decrypts secrets/ at activation. See .sops.yaml for which keys can read what.
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-k8s-node-1, home-manager, sops-nix, ... } @ inputs:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in
  {
    nixosConfigurations.home-pc = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/home-pc
        ./modules/common.nix
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users = {
            david = import ./home/david;
          };
        }
      ];
    };
    nixosConfigurations.unifi-controller = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        # No autoUpgrade here either; see the note in hosts/unifi-controller.
        ./hosts/unifi-controller
        ./modules/common.nix
      ];
    };
    nixosConfigurations.k8s-node-1 = nixpkgs-k8s-node-1.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        # No autoUpgrade here: each deploy restarts k3s, so it's upgraded by hand (see the cluster
        # README in ~/src/k8s).
        ./hosts/k8s-node-1
        ./modules/common.nix
      ];
    };
  };
}
