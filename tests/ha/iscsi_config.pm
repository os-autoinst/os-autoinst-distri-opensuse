use base "installbasetest";
use testapi;
use autotest;

sub run() {
    send_key 'ctrl-alt-g';
    type_string "yast iscsi-client\n";
    for my $i ( 1 .. 3 ) {
        assert_screen 'yast-iscsi-client-loaded';
        send_key 'ctrl-pgdn';
        sleep 2;
    }
    send_key 'alt-b';
    send_key 'alt-v';
    for my $i ( 1 .. 3 ) {
        assert_screen 'yast-iscsi-discovered-targets';
        send_key 'ctrl-pgdn';
        sleep 2;
    }
    send_key 'alt-d';
    for my $i ( 1 .. 3 ) {
        assert_screen 'yast-iscsi-initiator-discovery';
        send_key 'ctrl-pgdn';
        sleep 2;
    }
    send_key 'alt-i';
    sleep 1;
    type_string '10.0.2.15';
    sleep 1;
    send_key 'alt-n';
    for my $i ( 1 .. 3 ) {
        assert_screen 'yast-iscsi-discovered-targets';
        send_key 'ctrl-pgdn';
        sleep 2;
    }
    send_key 'alt-l';
    for my $i ( 1 .. 3 ) {
        assert_screen 'yast-iscsi-initiator-login';
        send_key 'ctrl-pgdn';
        sleep 2;
    }
    send_key 'alt-s';
    sleep 1;
    send_key 'down';
    sleep 1;
    send_key 'down';
    sleep 1;
    send_key 'ret';
    sleep 1;
    send_key 'alt-n';
    for my $i ( 1 .. 3 ) {
        assert_screen 'yast-iscsi-discovered-targets';
        send_key 'ctrl-pgdn';
        sleep 2;
    }
    send_key 'alt-o';
    sleep 5;
    send_key 'ctrl-l';
    assert_screen 'proxy-terminator-clean';
}

1;
