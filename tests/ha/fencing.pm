use base "installbasetest";
use testapi;
use autotest;

sub run() {
    type_string "crm node fence node2\n";
    assert_screen 'cluster-really-shoot-q';
    type_string "y\n";
    sleep 15;
    type_string "crm status\n";
    assert_screen 'cluster-node-down';
    sleep 240;
    send_key 'ctrl-l';
    type_string "crm status\n";
    assert_screen 'cluster-node-returned';
    send_key 'ctrl-l';
    send_key 'ctrl-pgdn';
    send_key 'ret';
    type_string "ssh 10.0.2.17 -l root\n";
    sleep 10;
    type_string "nots3cr3t\n";
    sleep 10;
    send_key 'ctrl-l';
    type_string "crm status\n";
    assert_screen 'cluster-status';
    send_key 'ctrl-l';
    send_key 'ctrl-pgup';
}

1;
