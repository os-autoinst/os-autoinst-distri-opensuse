use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;
    # Hostname
    send_key "alt-h";
    type_string "susetest";
    send_key "tab";
    type_string "zq1.de";

    # TODO: assert
    assert_screen 'hostname-typed', 4;
    send_key $cmd{next};

    # network conf
    assert_screen 'network-config-done', 40; # longwait Net|DSL|Modem
    send_key $cmd{next};

    assert_screen 'test-internet-connection', 30;
    send_key $cmd{next};

    # release notes download can take a while
    assert_screen 'internet-is-fine', 90;
    send_key $cmd{next};
}

1;
