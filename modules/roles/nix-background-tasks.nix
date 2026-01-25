{... }:
{
  config = {
    nix.gc = {
      automatic = true;
      dates = "Mon *-*-* 04:00:00";
      options = "--delete-older-than 31d";
    };
  };
}
