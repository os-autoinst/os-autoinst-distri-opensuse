use base "basetest";
use testapi;
use autotest;

sub run() {
    send_key 'shift-ctrl-alt-g';
    type_string "ha-cluster-init -y -s /device/path\n";
    assert_screen 'cluster-init';
    type_string "crm status\n";
    assert_screen 'cluster-status';
}

1;
