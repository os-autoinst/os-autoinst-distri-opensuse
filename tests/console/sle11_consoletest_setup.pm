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
use strict;
use testapi;
use utils;

sub run() {
    my $self = shift;

    # let's see how it looks at the beginning
    save_screenshot;

    # verify there is a text console on tty1
    send_key "ctrl-alt-f1";
    assert_screen_with_soft_timeout("tty1-selected", soft_timeout => 15);

    # init
    # log into text console
    send_key "ctrl-alt-f4";
    # we need to wait more than five seconds here to pass the idle timeout in
    # case the system is still booting (https://bugzilla.novell.com/show_bug.cgi?id=895602)
    assert_screen_with_soft_timeout("tty4-selected", soft_timeout => 10);
    assert_screen "text-login", 10;
    type_string "$username\n";
    if (!get_var("LIVETEST")) {
        assert_screen_with_soft_timeout("password-prompt", soft_timeout => 10);
        type_password;
        type_string "\n";
    }
    sleep 3;
    $self->set_standard_prompt();
    sleep 1;

    script_sudo "chown $username /dev/$serialdev";

    become_root;
    script_run "chmod 444 /usr/sbin/packagekitd";    # packagekitd will be not executable
    type_string "exit\n";

    save_screenshot;
    clear_console;

    assert_script_run("curl -L -v -f " . autoinst_url . "/data > test.data");
    assert_script_run " cpio -id < test.data";
    script_run "ls -al data";

    save_screenshot;
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
