use base "installbasetest";
use testapi;
use autotest;

sub joincluster(){
    type_string "sleha-join -y -c 10.0.2.16\n";
    assert_screen 'cluster-join';
    type_string "crm status\n";
    assert_screen 'cluster-status';
}

sub run() {
    send_key 'ctrl-pgdn';
    for my $i ( 1 .. 2 ) {
        joincluster();
        send_key 'ctrl-pgdn'
    }
}

1;
