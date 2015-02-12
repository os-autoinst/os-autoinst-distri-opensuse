use base "installbasetest";
use strict;
use testapi;

sub reconnecthainstall($) {
    my ($nodenum) = @_;
    my $nodeip = 5+$nodenum;
    type_string "ssh 10.0.2.1$nodeip -l root\n";
    sleep 1;
    type_string "openqaha\n";
    sleep 1;
    type_string "/usr/lib/YaST2/startup/YaST2.ssh\n";
    assert_screen 'second-stage', 15;
}

sub run() {
    sleep 60; #should be 500ish, hacked for testing
    send_key 'shift-ctrl-alt-g';
     for my $i ( 1 .. 1 ) { #should be 3, hacked for quick testing
        reconnecthainstall "$i";
        #send_key 'ctrl-pgdn';
    }
    send_key 'ctrl-alt-g';
}

1;
# vim: set sw=4 et:
