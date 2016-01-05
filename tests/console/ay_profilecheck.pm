use base "consoletest";
use testapi;

# This test only succeeds if system is booted with static network config like this:
# EXTRABOOTPARAMS="ifcfg='eth0=10.0.2.22/24,10.0.2.2,10.0.2.3,susetest'"

sub run() {
    my $self      = shift;
    my $ayprofile = '/root/autoinst.xml';

    become_root;
    script_run "ls -al $ayprofile";

    # Checking for default route (bsc#956012)
    assert_script_run("grep '<gateway>' $ayprofile");

    # Not yet ready:
    # Checking for domain and hostname (bsc#957377)
    #assert_script_run("grep '<domain>' $ayprofile");
    #assert_script_run("grep '<hostname>' $ayprofile");

    script_run "exit";
}

1;
# vim: set sw=4 et:
