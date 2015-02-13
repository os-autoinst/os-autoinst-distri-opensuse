use base "installbasetest";
use strict;
use testapi;

sub starthainstall($) {
    my ($nodenum) = @_;
    my $nodeip = 5+$nodenum;
    type_string "ssh 10.0.2.1$nodeip -l root\n";
    sleep 1;
    type_string "yes\n";
    type_string "openqaha\n";
    sleep 1;
    type_string "yast\n";
    assert_screen 'inst-welcome-start', 15;
}

sub run() {
    assert_screen 'proxy-terminator-clean';
    for my $i ( 1 .. 3 ) {
        starthainstall "$i";
        send_key 'ctrl-pgdn';
    }
    send_key 'ctrl-alt-g'; #group all tabs together (changed in the vm from meta-g default)
}

1;
