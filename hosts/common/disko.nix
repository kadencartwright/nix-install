{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-id/replace-me";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "fmask=0137"
                "dmask=0027"
              ];
            };
          };

          cryptroot = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptlvm";
              content = {
                type = "lvm_pv";
                vg = "vg1";
              };
            };
          };
        };
      };
    };

    lvm_vg.vg1 = {
      type = "lvm_vg";
      lvs.root = {
        size = "100%FREE";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/";
          extraArgs = [
            "-m"
            "1"
          ];
        };
      };
    };
  };
}
