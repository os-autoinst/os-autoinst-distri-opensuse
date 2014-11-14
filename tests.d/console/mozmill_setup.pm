use base "consolestep";
use bmwqemu;

# http://mozmill-crowd.blargon7.com/#/functional/reports

sub is_applicable() {
    my $self = shift;
    return consolestep_is_applicable && $vars{MOZILLATEST};
}

sub run() {
    my $self = shift;
    script_sudo("zypper -n in gcc python-devel python-pip mercurial curlftpfs");
    assert_screen 'test-mozmill_setup-1', 3;
    send_key "ctrl-l";

    #script_sudo("pip install mozmill mercurial");
    script_sudo("pip install mozmill mercurial");

    #script_sudo("pip install mozmill==1.5.3 mercurial");
    sleep 5;
    wait_idle 50;
    assert_screen 'test-mozmill_setup-2', 3;
    send_key "ctrl-l";
    script_run("cd /tmp");    # dont use home to not confuse dolphin test
    script_run("wget -q openqa.opensuse.org/opensuse/qatests/qa_mozmill_setup.sh");
    local $bmwqemu::timesidleneeded = 3;
    script_run("sh -x qa_mozmill_setup.sh");
    sleep 9;
    wait_idle 90;
    wait_serial("qa_mozmill_setup.sh done", 120) || die 'setup failed';
    save_screenshot;
}

1;
# vim: set sw=4 et:
