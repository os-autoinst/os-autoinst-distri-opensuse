use base "bigconsolestep";
use bmwqemu;

# for https://bugzilla.novell.com/show_bug.cgi?id=657626
sub run() {
    my $self = shift;
    script_run("cd /tmp ; wget -q openqa.opensuse.org/opensuse/qatests/qa_ntp.pl");
    script_sudo("perl qa_ntp.pl");
    wait_idle 90;
    assert_screen 'test-sntp-1', 3;
    send_key "ctrl-l";    # clear screen
    script_run('echo sntp returned $?');
    assert_screen 'test-sntp-2', 3;
}

1;
# vim: set sw=4 et:
