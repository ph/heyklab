{
  virtualisation.libvirt.connections."qemu:///system".domains.ubuntu-vm = {
    memory = 2048; # MB
    vcpu = 2;

    disk = [
      {
        volume = {
          pool = "default";
          size = 20 * 1024 * 1024 * 1024; # 20GB
        };
      }
    ];

    network = [
      {
        network = "default";
      }
    ];

    installationMedia = {
      source = "https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso";
    };
  };
}
