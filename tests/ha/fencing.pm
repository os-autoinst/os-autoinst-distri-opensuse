use base "installbasetest";
use testapi;
use autotest;

sub run() {
    type_string "crm node fence node2\n";
    sleep 20;
    type_string "crm status\n";
    assert_screen 'cluster-node-down';
    sleep 120;
    type_string "crm status\n";
    assert_screen 'cluster-node-returned';
    send_key 'ctrl-l';
    send_key 'ctrl-pgdn';
    send_key 'ret';
    type_string "ssh 10.0.2.17 -l root\n";
    sleep 1;
    type_string "openqaha\n";
    sleep 1;
    send_key 'ctrl-l';
    type_string "crm status\n";
    assert_screen 'cluster-status';
    send_key 'ctrl-l';
    send_key 'ctrl-pgup';
}

1;
