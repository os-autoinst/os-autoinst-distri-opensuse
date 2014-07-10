use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;

    send_key "ctrl-l";
    script_sudo("hostname susetest");
    script_run('echo $?; hostname');
    assert_screen("hostname");
}

sub test_flags() {
    return { 'important' => 1, 'milestone' => 1, 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
