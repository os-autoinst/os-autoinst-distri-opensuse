use base "basetest";
use bmwqemu;

sub is_applicable {
    return $vars{DESKTOP} !~ /textmode/;
}

sub run() {
    my $self = shift;

    send_key "ctrl-l";
    script_run('ps -ef | grep Xorg');
    assert_screen("xorg-tty7"); # suppose used terminal is tty7
}

1;
# vim: set sw=4 et:
