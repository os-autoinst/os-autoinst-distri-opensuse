use base "installbasetest";
use testapi;
use autotest;

sub run() {
    send_key 'shift-ctrl-alt-g';
    type_string "ha-cluster-init -y -s /dev/disk/by-id/scsi-1LIO-ORG.FILEIO:348cfd84-58a1-426e-9797-e22f04cf207f\n";
    assert_screen 'cluster-init', 60;
    type_string "crm status\n";
    assert_screen 'cluster-status';
    send_key 'ctrl-l';
}

1;
