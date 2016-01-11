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

    script_run("zypper -n patch --with-interactive -l; echo 'worked-patch-\$?' > /dev/$serialdev");
    $ret = wait_serial "worked-patch-\?-", 700;
    $ret =~ /worked-patch-(\d+)/;
    die "zypper failed with code $1" unless $1 == 0 || $1 == 102 || $1 == 103;

    script_run("zypper -n patch --with-interactive -l; echo 'worked-2-patch-\$?-' > /dev/$serialdev");    # first one might only have installed "update-test-affects-package-manager"
    $ret = wait_serial "worked-2-patch-\?-", 1500;
    $ret =~ /worked-2-patch-(\d+)/;
    die "zypper failed with code $1" unless $1 == 0 || $1 == 102;

    assert_script_run("rpm -q libzypp zypper");

    # XXX: does this below make any sense? what if updates got
    # published meanwhile?
    send_key "ctrl-l";    # clear screen to see that second update does not do any more
    assert_script_run("zypper -n -q patch");

    script_run('exit');
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
