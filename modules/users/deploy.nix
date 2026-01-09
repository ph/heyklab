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
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiRJsoVbDvQYsRe94WC0kaRrru1+loCl6xZecdR4kEMfuJWz4NvyZNgD2q7KtXmQ+flvIdPuN0uxHbIzm+f1L500ZGoeOSo9GT2HPSJT8nUjgzLzKkwEs35uraxMQicjEnoUf9v+qx7s8Tv/mmKuMPrqMiNt337PlEL6llRkNtJ8srOd8pDXd40WOtHcPjRN0if78VnjESDTufAuqLoGs6yCe5j3QpcGlFneQ164AATwUMcuMQc9TVFc2pRjZRaWOFDSIAqF6NsaE3D4K6NvbTl8YIhi/seGKkvp6jfnv4T53JnY4TwbOEyPUS9dp3yfaz3NThy5r1AYAETz9s8mJC4KT2dKatShzU9tGGCyg409HNe/nOZQZrpBzfYLLwiBkxSZaCesJ0s4tyiKNW26asub0rM9DTnfCbcrEzzRtmCph3yZIC7yvNl3BAhKGIodsC07tk5zCR+kTyLntRBTIvev7Y98jz0/WA2Jaa3tQZCH8vhF0PCeiPh5c+z4A2z19ZdsLauKUs833Tj5amZg6H8t67pyFXGa2N8dptzsssk/BDEdO/YT6hohjEFI9kqtvNQbtTi6vwHjPCkpeV8MDRHWDNZsnLVz/2VR8oLH2suWDKGz4GlY0DfWRnmswu2rijGkD7U8eHt/6xrrtVxWZ9yJGnc90+RKz1LjwReRmkPw== openpgp:0xC6D3E079"
    ];
  };

  security.sudo.extraRules = [
    {
      users = ["deploy"];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}
