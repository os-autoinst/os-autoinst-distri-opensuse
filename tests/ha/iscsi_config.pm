use base "basetest";
use testapi;
use autotest;

sub run() {
    type_string "zypper in -n yast2-iscsi-client open-iscsi\n";
    send_key 'shift-ctrl-alt-g';
    type_string "echo 'InitiatorName=iqn.1996-04.de.suse:01:8f4aff8c879' > /etc/iscsi/initatorname.iscsi";
    send_key 'ctrl-pgdn';
    type_string "echo 'InitiatorName=iqn.1996-04.de.suse:01:8f4aff8c878' > /etc/iscsi/initatorname.iscsi";
    send_key 'ctrl-pgdn';
    type_string "echo 'InitiatorName=iqn.1996-04.de.suse:01:8f4aff8c877' > /etc/iscsi/initatorname.iscsi";
    send_key 'ctrl-pgup';
    send_key 'ctrl-pgup';
    send_key 'ctrl-alt-g';
    type_string "yast iscsi-client\n";
    assert_screen 'yast-iscsi-client-loaded';
    send_key 'alt-b';
    send_key 'alt-v';
    assert_screen 'yast-iscsi-discovered-targets';
    send_key 'alt-d';
    assert_screen 'yast-iscsi-initiator-discovery';
    send_key 'alt-i';
    type_string '10.0.2.12';
    send_key 'alt-n';
    assert_screen 'yast-iscsi-discovered-targets';
    send_key 'alt-l';
    assert_screen 'yast-iscsi-initiator-login';
    send_key 'alt-s';
    send_key 'down';
    send_key 'down';
    send_key 'ret';
    send_key 'alt-n';
    assert_screen 'yast-iscsi-initiator-discovery';
    send_key 'alt-o';
    sleep 5;
    send_key 'alt-l';
    assert_screen 'proxy-terminator-clean';
}

1;
