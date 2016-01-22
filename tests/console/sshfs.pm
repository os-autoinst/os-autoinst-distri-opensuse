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

sub run() {
    my $self = shift;
    become_root();
    script_run("zypper -n in sshfs");
    wait_still_screen(12, 90);
    script_run('cd /var/tmp ; mkdir mnt ; sshfs localhost:/ mnt');
    assert_screen "accept-ssh-host-key", 3;
    type_string "yes\n";    # trust ssh host key
    assert_screen 'password-prompt';
    type_password;
    send_key "ret";
    assert_screen 'sshfs-accepted', 3;
    script_run('cd mnt/tmp');
    script_run("zypper -n in xdelta");
    script_run("rpm -e xdelta");
    script_run('cd /tmp');

    # we need to umount that otherwise root is considered logged in!
    script_run("umount /var/tmp/mnt");

    # become user again
    type_string "exit\n";
    assert_screen 'test-sshfs-1', 3;
}

1;
# vim: set sw=4 et:
