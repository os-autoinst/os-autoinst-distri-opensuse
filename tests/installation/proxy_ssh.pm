use base "installbasetest";
use strict;
use testapi;

sub startsshinstall($) {
    my ($nodenum) = @_;
    my $nodeip = 5+$nodenum;
    type_string "ssh 10.0.2.1$nodeip -l root\n";
    sleep 10;
    type_string "yes\n";
    type_string "openqaha\n";
    sleep 10;
    type_string "yast\n";
    assert_screen 'inst-welcome-start', 15;
}

sub run() {
    assert_screen 'proxy-terminator-clean';
    startsshinstall "1"; # only need one VM now
}

1;
