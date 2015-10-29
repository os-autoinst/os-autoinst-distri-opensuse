use base "hacluster";
use testapi;
use lockapi;
use Time::HiRes qw(sleep);

sub run() {
    script_run "ha-cluster-init"; 
    assert_screen "ha-cluster-init-watchdog-warning";
    send_key "ctrl-c";
    script_run "echo softdog > /etc/modules-load.d/softdog.conf";
    script_run "systemctl restart systemd-modules-load.service";
    script_run "echo \"softdog=`lsmod | grep softdog | wc -l`\" > /dev/$serialdev";
    die "softdog module not loaded" unless wait_serial "softdog=1", 20;
    send_key "ctrl-l"; #clear screen
}

sub test_flags {
    return { milestone => 1, fatal => 1, important => 1 };
}

1;
