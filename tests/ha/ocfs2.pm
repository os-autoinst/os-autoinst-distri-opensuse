use base "installbasetest";
use testapi;
use autotest;

sub run() {
    assert_and_click 'hawk-wizard-icon';
    assert_and_click 'hawk-ocfs2-wizard';
    assert_and_click 'hawk-wizard-next';
    assert_and_click 'hawk-block-device';
    type_string '/dev/path/to/storage/device';
    assert_and_click 'hawk-wizard-next';
    assert_screen 'hawk-wizard-confirm';
    assert_and_click 'hawk-wizard-next';
    assert_screen 'hawk-dashboard';
    send_key 'alt-f4';
    type_string "ssh 10.0.2.16 -l root\n";
    sleep 1;
    type_string "openqaha\n";
    sleep 1;
    type_string "mkfs.ocfs2 /dev/path/to/storage/device\n";
    type_string "crm resource online clusterfs\n";
    type_string "crm status\n";
    assert_screen 'crm-ocfs-running';
}

1;
