use base "x11step";
use testapi;

# for https://bugzilla.novell.com/show_bug.cgi?id=657626

sub run() {
    my $self = shift;
    x11_start_program("xterm");
    script_run("cd /tmp");
    script_run("wget -q openqa.opensuse.org/opensuse/qatests/qa_mozmill_run.sh");
    local $vars{SCREENSHOTINTERVAL} = 0.25;
    script_run("sh -x qa_mozmill_run.sh");
    sleep 30;
    local $bmwqemu::timesidleneeded = 4;

    for ( 1 .. 12 ) {    # one test takes ~7 mins
        send_key "shift";    # avoid blank/screensaver
        last if wait_serial "mozmill testrun finished", 120;
    }
    assert_screen 'test-mozmill_run-1', 3;
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
