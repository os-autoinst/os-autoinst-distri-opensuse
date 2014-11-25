use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    script_sudo("hostname susetest");
    script_run('echo $?; hostname');
    assert_screen("hostname");
}

sub test_flags() {
    return { 'important' => 1, 'milestone' => 1, 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
