use base "consolestep";
use testapi;

sub run() {
    my $self = shift;

    send_key "ctrl-l";
    script_run('ps -ef | grep bin/X');
    assert_screen("xorg-tty7"); # suppose used terminal is tty7
}

sub test_flags() {
    return { 'important' => 1 };
}

1;
# vim: set sw=4 et:
