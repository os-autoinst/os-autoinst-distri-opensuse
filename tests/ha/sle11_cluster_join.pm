use base "installbasetest";
use testapi;
use autotest;

sub joincluster(){
    type_string "sleha-join -y -c 10.0.2.16\n";
    assert_screen 'cluster-join-password';
    type_string "nots3cr3t\n";
    assert_screen 'cluster-join-finished';
    type_string "crm status\n";
    assert_screen 'cluster-status';
    send_key 'ctrl-l';
}

sub run() {
    send_key 'ctrl-pgdn';
    for my $i ( 1 .. 2 ) {
        joincluster();
        send_key 'ctrl-pgdn';
    }
}

1;
