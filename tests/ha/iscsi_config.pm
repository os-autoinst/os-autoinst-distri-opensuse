use base "installbasetest";
use testapi;
use autotest;

sub run() {
    if (check_var('DESKTOP', 'textmode')) {
        assert_screen 'linux-login', 200;
    }
    type_string "zypper -n in yast2-iscsi-client open-iscsi\n";
    sleep 60; # Give it some time to do the install
    type_string "echo '10.0.2.16    node1' >> /etc/hosts\n";
    type_string "echo '10.0.2.17    node2' >> /etc/hosts\n";
    type_string "echo '10.0.2.18    node3' >> /etc/hosts\n";
    send_key 'shift-ctrl-alt-g';
    type_string "echo 'InitiatorName=iqn.1996-04.de.suse:01:8f4aff8c879' > /etc/iscsi/initiatorname.iscsi\n";
    type_string "echo 'node1' > /etc/hostname\n";
    type_string "echo 'node1' > /etc/HOSTNAME\n";
    type_string "hostname node1\n";
    send_key 'ctrl-pgdn';
    type_string "echo 'InitiatorName=iqn.1996-04.de.suse:01:8f4aff8c878' > /etc/iscsi/initiatorname.iscsi\n";
    type_string "echo 'node2' > /etc/hostname\n";
    type_string "echo 'node2' > /etc/HOSTNAME\n";
    type_string "hostname node2\n";
    send_key 'ctrl-pgdn';
    type_string "echo 'InitiatorName=iqn.1996-04.de.suse:01:8f4aff8c877' > /etc/iscsi/initiatorname.iscsi\n";
    type_string "echo 'node3' > /etc/hostname\n";
    type_string "echo 'node3' > /etc/HOSTNAME\n";
    type_string "hostname node3\n";
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
    type_string '10.0.2.15';
    send_key 'alt-n';
    assert_screen 'yast-iscsi-discovered-targets';
    send_key 'alt-l';
    assert_screen 'yast-iscsi-initiator-login';
    send_key 'alt-s';
    send_key 'down';
    send_key 'down';
    send_key 'ret';
    send_key 'alt-n';
    assert_screen 'yast-iscsi-discovered-targets';
    send_key 'alt-o';
    sleep 5;
    send_key 'ctrl-l';
    assert_screen 'proxy-terminator-clean';
}

1;
