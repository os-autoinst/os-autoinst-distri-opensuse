use base "basetest";
use testapi;
use autotest;

sub connectssh($) {
    my ($nodenum) = @_;
    my $nodeip = 5+$nodenum;
    type_string "ssh 10.0.2.1$nodeip -l root\n";
    sleep 1;
    type_string "openqaha\n";
    sleep 1;
}

sub run() {
    assert_screen 'proxy-terminator-clean';
    send_key 'shift-ctrl-alt-g';
    for my $i ( 1 .. 3 ) { 
        connectssh "$i";
        send_key 'ctrl-pgdn';
    }
    send_key 'ctrl-alt-g';
}

1;
