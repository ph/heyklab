{ ... }:
{
  users.users.deploy = {
    isNormalUser = true;
    hashedPassword = "!";
    home = "/home/deploy";
    description = "Deploy machine";
    extraGroups = [
      "wheel"
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO7WiMbqiYriD1kyTQxUJgpfia8E31rJ6acC5Zp43Yfg openpgp:0x04795C04"
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ "deploy" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
