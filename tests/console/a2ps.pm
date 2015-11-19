use strict;
use base "consoletest";
use testapi;
use ttylogin;

# a2ps is available by default only in openSUSE*

sub run() {
    become_root;
    assert_script_run("zypper -n in a2ps");
    assert_script_run("curl https://www.suse.com -o /tmp/suse.html");
    assert_script_run("a2ps -o /tmp/suse.ps /tmp/suse.html");
    assert_screen "a2ps_saved";
}

1;
