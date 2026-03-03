{nixvirt, pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };

  virtualisation.libvirt.verbose = true;

  # virtualisation.libvirt.swtpm.enable = true;
  virtualisation.libvirt.connections."qemu:///session".domains =
    [
      {
        definition = nixvirt.lib.domain.writeXML (nixvirt.lib.domain.templates.linux
          {
            name = "oops";
            uuid = "def734bb-e2ca-44ee-80f5-0ea0f2593aaa";
            memory = { count = 4; unit = "GiB"; };
            storage_vol = { pool = "MyPool"; volume = "ooops.qcow2"; };
            # backing_vol = /home/ashley/VM-Storage/Base.qcow2;
            install_vol = "https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso";
            bridge_name = "virbr0";
            # nvram_path = /home/ashley/VM-Storage/Bellevue.nvram;
            virtio_net = true;
            virtio_drive = true;
            install_virtio = true;
          });
      }
    ];
}
