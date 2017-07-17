# Piglit X11 regression tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Piglit testsuite
# Maintainer: Ondřej Súkup <osukup@suse.cz>


use strict;
use warnings;

use base "x11regressiontest";
use testapi;
use utils;


sub run {
    select_console('root-console');
    pkcon_quit;

    # install piglit testsuite from distribution repository (Tumbleweed) or from defined
    # PIGLIT_REPO (SLES)
    if (my $piglit_repo = get_var('PIGLIT_REPO')) {
        zypper_call("ar -f $piglit_repo piglit_repo");
        zypper_call("--gpg-auto-import-keys ref");
    }

    zypper_call("in piglit", exitcode => [0, 102, 103]);

    select_console('x11');
    x11_start_program('xterm');

    # prepare results dir
    script_run("mkdir -p /tmp/p_results");

    # start piglit testsuite with correct list of skipped tests,
    # it is hardware demading and on lower spec takes over one hour to run
    # And also VNC-stalls because full load on VM
    if (check_var('DISTRI', 'opensuse')) {
        assert_script_run("piglit run /usr/lib64/piglit/tests/opensuse_qa.py /tmp/p_results", 1.5 * 60 * 60);
    }
    else {
        assert_script_run("piglit run /usr/lib64/piglit/tests/suse_qa.py /tmp/p_results", 1.5 * 60 * 60);
    }

    # recover from VNC stall, and unlock desktop
    wait_screen_change { send_key('ret'); };
    ensure_unlocked_desktop;
    send_key('ret');
    wait_still_screen;
    # upload results
    upload_logs("/tmp/p_results/results.json.bz2");
    # upload results in human readable format
    script_run("piglit summary console /tmp/p_results > /tmp/piglit.log");
    upload_logs("/tmp/piglit.log");
    # if any test crash mark test as failed
    assert_script_run('! grep ": crash" < /tmp/piglit.log', 90);
}

sub post_fail_hook {
    select_console('root-console');
    # tar coredumps and uplad resultinf tar to assests
    script_run("tar -cf /tmp/core.tar /var/lib/systemd/coredump/*");
    upload_logs("/tmp/core.tar");
    select_console('x11');
}
1;
