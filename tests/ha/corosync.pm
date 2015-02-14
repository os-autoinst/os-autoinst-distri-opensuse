use base "installbasetest";
use testapi;
use autotest;

sub run() {
    for my $i ( 1 .. 3 ) {
            type_string "crm status\n";
            assert_screen 'cluster-status';
            send_key 'ctrl-pgdn'
        }
}

1;
