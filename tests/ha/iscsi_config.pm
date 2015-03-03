use base "installbasetest";
use testapi;
use autotest;

sub run() {
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
