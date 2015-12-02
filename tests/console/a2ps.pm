use strict;
use base "consoletest";
use testapi;
use ttylogin;

sub run() {
    become_root;
    assert_script_run("systemctl stop packagekit.service");
    assert_script_run("zypper -n in a2ps");
    assert_script_run("curl https://www.suse.com > /tmp/suse.html");
    validate_script_output "a2ps -o /tmp/suse.ps /tmp/suse.html 2>&1", sub { m/saved into the file/ }, 3;
    script_run('exit');
}

1;
#vim: set sw=4 et:

