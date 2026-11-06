{ ... }:

# Settings every host gets.
{
  # Automatic upgrades leave a new generation behind each time, so clean up regularly or the
  # store fills the disk. Keeps two weeks of generations to roll back to.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    randomizedDelaySec = "1h";
    persistent = true;
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;
}
