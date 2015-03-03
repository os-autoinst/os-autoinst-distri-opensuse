use base "installbasetest";
use strict;
use testapi;

sub starthainstall($) {
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
    for my $i ( 1 .. 1 ) { #FIXME - Reduced to one to do cloning instead
        starthainstall "$i";
        #send_key 'ctrl-pgdn'; #FIXME - Removed as no longer installing in parralel
    }
    #send_key 'ctrl-alt-g'; #group all tabs together (changed in the vm from meta-g default) #FIXME - Removed as no longer installing in parralel
}

1;
