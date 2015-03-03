use base "installbasetest";
use strict;
use testapi;

sub reconnectsshinstall($) {
    my ($nodenum) = @_;
    my $nodeip = 5+$nodenum;
    type_string "ssh 10.0.2.1$nodeip -l root\n";
    sleep 10;
    type_string "openqaha\n";
    sleep 10;
    type_string "/usr/lib/YaST2/startup/YaST2.ssh\n";
    assert_screen 'second-stage', 40;
}

sub run() {
    sleep 240; #500 is too long, seems to shut down the VMs
    reconnectsshinstall "1";
}

1;
# vim: set sw=4 et:
