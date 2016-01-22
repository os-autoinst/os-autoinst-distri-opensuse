# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;
use utils;


sub run() {
    my $self = shift;

    # let's see how it looks at the beginning
    save_screenshot;

    if (!check_var('ARCH', 's390x')) {
        # verify there is a text console on tty1
        send_key "ctrl-alt-f1";
        assert_screen "tty1-selected", 15;
    }

    # init
    select_console 'user-console';

    become_root;
    script_run "chown $username /dev/$serialdev";
    # Export the existing status of running tasks for future reference (fail would export it again)
    type_string "ps axf > /tmp/psaxf_consoletest_setup.log\n";
    upload_logs "/tmp/psaxf_consoletest_setup.log";
    save_screenshot;

    # Stop packagekit
    script_run "systemctl mask packagekit.service";
    script_run "systemctl stop packagekit.service";
    # Installing a minimal system gives a pattern conflicting with anything not minimal
    # Let's uninstall 'the pattern' (no packages affected) in order to be able to install stuff
    script_run "zypper -n rm patterns-openSUSE-minimal_base-conflicts";
    # Install curl and tar in order to get the test data
    assert_script_run "zypper -n install curl tar";
    type_string "exit\n";

    save_screenshot;
    clear_console;

    assert_script_run "curl -L -v " . autoinst_url('/data') . " > test.data";
    assert_script_run " cpio -id < test.data";
    script_run "ls -al data";

    save_screenshot;
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
