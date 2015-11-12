use strict;
use base "consoletest";
use testapi;
use ttylogin;

sub run() {
    become_root;
    assert_script_run("zypper -n in a2ps | tee /dev/$serialdev");
    assert_script_run("curl https://www.suse.com > /tmp/suse.html");
    assert_script_run("a2ps -o /tmp/suse.ps /tmp/suse.html | tee /dev/$serialdev");
    assert_screen "a2ps_saved", 5;
}

1;
