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

sub run() {
    select_console 'root-console';

    assert_script_run("zypper -n in sshfs");
    script_run('cd /var/tmp ; mkdir mnt ; sshfs localhost:/ mnt', 0);
    assert_screen "accept-ssh-host-key";
    type_string "yes\n";    # trust ssh host key
    assert_screen 'password-prompt';
    type_password;
    send_key "ret";
    assert_screen 'sshfs-accepted';
    script_run('cd mnt/tmp');
    assert_script_run("zypper -n in xdelta");
    assert_script_run("rpm -e xdelta");
    script_run('cd /tmp');

    # we need to umount that otherwise root is considered logged in!
    assert_script_run("umount /var/tmp/mnt");
}

1;
# vim: set sw=4 et:
