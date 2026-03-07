{lib, pkgs, ...}: 
let
  publickey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC2e00/VCmGOXv8NDH+hjuhJLjPu6KSVzwZOv8QwF8Yn samuel@TheSpaceStation";
in
{
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
  };
  networking.hostName = "curiosity";
  networking.firewall.allowedTCPPorts = [3001 22];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git # used by nix flakes
    curl

    neofetch
    lm_sensors # `sensors`
    btop # monitor system resources

    # Peripherals
    mtdutils
    i2c-tools
    minicom
  ];

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      X11Forwarding = true;
      PasswordAuthentication = true;
    };
    openFirewall = true;
  };

  # =========================================================================
  #      Users & Groups NixOS Configuration
  # =========================================================================

  # TODO Define a user account. Don't forget to update this!
  users.users.rk = {
    password = "superepicpassword";
    isNormalUser = true;
    home = "/home/rk";
    extraGroups = ["users" "wheel"];
    openssh.authorizedKeys.keys = [
      publickey
    ];
  };

  # enable closed source packages
  nixpkgs.config.allowUnfree = true;

  users.users.root.openssh.authorizedKeys.keys = [
    publickey
  ];

  system.stateVersion = "26.05";
}