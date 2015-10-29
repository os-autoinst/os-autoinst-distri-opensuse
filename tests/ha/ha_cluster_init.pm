use base "hacluster";
use testapi;

sub run() {
   script_run "systemctl restart wicked.service", 60; #update dynamic DNS just in case
   script_run "ha-cluster-init"; 
   assert_screen "ha-cluster-init-watchdog-warning";
   send_key "ctrl-c";
   script_run "echo softdog > /etc/modules-load.d/softdog.conf";
   script_run "systemctl restart systemd-modules-load.service";
   script_run "echo \"softdog=`lsmod | grep softdog | wc -l`\" > /dev/$serialdev";
   wait_serial("softdog=1"); #softdog is enabled
   send_key "ctrl-l"; #clear screen
   script_run "ha-cluster-init"; 
   assert_screen "ha-cluster-init-network-address-to-bind";
   send_key "ret";
   assert_screen "ha-cluster-init-multicast-address";
   send_key "ret";
   assert_screen "ha-cluster-init-multicast-port";
   send_key "ret";
   assert_screen "ha-cluster-init-configure-sbd";
   type_string "y\n";
   assert_screen "ha-cluster-init-configure-sbd-path";
   #FIXME: I don't like the path here
   type_string "/dev/disk/by-path/ip-*-lun-0\n";
   assert_screen "ha-cluster-init-configure-sbd-confirmation";
   type_string "y\n";
   assert_screen "ha-cluster-init-administration-ip", 180;
   type_string "n\n";
   assert_screen "ha-cluster-init-done";
   upload_logs "/var/log/ha-cluster-bootstrap.log";
   
}

sub test_flags {
    return { milestone => 1, fatal => 1, important => 1 };
}

1;
