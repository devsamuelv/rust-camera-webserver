{lib, self, pkgs, ...}: 
let
  publickey = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC2e00/VCmGOXv8NDH+hjuhJLjPu6KSVzwZOv8QwF8Yn samuel@TheSpaceStation"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJm0xjPOnvKlT9gnNlW3L9yuEoISEBLH9Ou3cn4wPBBs"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCkeQ0MSty9182D2XX5mqaN/NF9ijHh8G04BxOkEKM9ABLf0ytQBFDSjHONoYemQgaLRw+dMWW9tNuHC7/6I4PlEOSzJHBlWCjVDwC/D7koT4MhSJAKCFYVCOK4hvf6gf+MkZKaJcbTlNpDHje3WB//emoMvMfht1Eazl6nIUQSeI8GVSOQb8eWVDFHcQSzDAPZejce3McWs9Dl8ILFN123TDXq5n0qzukq0yi5O3U+DzUIXMG7A6V0vuZ1Juks4Jg7J+LBx2X3cLpJ5/s4Gm66DDPGoDmnQHXUFfVqwDq11LeNjl4lNxQxvnq4aamVItWy+pd52FsC/pWswx5M2PO/5hADUuO0RUpQzkvCg3kXGklZ8BdC5vP5j4y5TvT8LrIhEl8O+kqBcWTFonvyoSK8s7xyOZLOk5nzVep/qdnhOsyOMb8hM/xUhyPER4zxHZF9yAjBdyd2OYxqUh09x2zE/jhqYdplEv4Zw2Kt9bSzI1+2VR0lKzBRVW1D4yV96UW7xFKpFi5/1krZm23xG4lKZ7o6Tbv/4+3c6njljv3WiQuNBxligbU6qBXxgIqomDw0ZrZ18DXcXQ8oIuf0FrLerBQdk0H7BcQWcL+6DJOBml/yGi9U4jmw91fdSf1ZVIWx/f3H4yuXGD6EACJBMw5Sdqlzq1q6pMzQ0E0f/6r3rQ=="
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCpv4hyo6JLrJQ80rAIb0tQfNro323iyY4YwV/Dpvt88JlnzUGvX160NqTbKZnGkdSrJqtOvGya2aGhdnj/5Wi8PnFoV+E1kWSoyW0dVMEukWrR6pIEzoxEApQ12ROFqsCK9N6IWVB6JHlNH0sqglyQL025WE89OQZEJy2E4w2kAmuRZfYxhMWJkp7cFn7NefMh6YG1J6ZZ75lKcQN65wiJ2sH/d6ujFVS6cX98kU2qkibJ8BuyD83RYBl8U0SoiD1MLd7LqDYHkPEm68mJT/ewP7WgdPPoKuj2+YAKr8Z6DTtHzDW9oehIwxfNssum/ZuBqBKHcfCUPfz1TC8habuxIo5vhgcB/9o/424DPQDzWcdURbBrEw4Tx7Y3ykiyMJ4Z5QAL9RDac+mju7RvIyXt51kXChBSenEMhu7hzFcUIGaXEBnRlu8eaH2da6eebDWc2nEDhG4TU3sb4YA/P9QFdW+JCyS9t7D90UgjhIan3u0kNzzbsieiMc9DETy8sak="
  ];
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
    libjxl
    libcamera
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
    openssh.authorizedKeys.keys = publickey;
  };

  # enable closed source packages
  nixpkgs.config.allowUnfree = true;

  # Root should be locked down (no network credentials)
  users.users.root.openssh.authorizedKeys.keys = [];

  system.stateVersion = "26.05";
}