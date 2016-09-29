# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Rework the tests layout.
# G-Maintainer: Alberto Planas <aplanas@suse.com>

use base "installbasetest";
use strict;
use testapi;
use utils;

sub run() {
    my $self = shift;

    wait_boot;

    if (get_var('ZDUP_IN_X')) {
        x11_start_program('xterm');
        become_root;
    }
    else {
        # Remove the graphical stuff
        # This do not work in 13.2
        # script_sudo "/sbin/init 3";

        select_console('root-console');

        # Remove the --force when this is fixed:
        # https://bugzilla.redhat.com/show_bug.cgi?id=1075131
        if (check_var('HDDVERSION', "SLES-11")) {    #set default runlevel 3 for sle11
            type_string "sed -i 's/id:5:initdefault:/id:3:initdefault:/g' /etc/inittab\n";
        }
        else {
            script_run("systemctl set-default --force multi-user.target");
        }
        # The CD was ejected in the bootloader test
        type_string("/sbin/reboot\n");

        reset_consoles;
        wait_boot textmode => 1;

        select_console('root-console');
    }

    if (get_var('HDD_1', '') =~ /opensuse-13\.2/) {
        record_soft_failure 'bsc#949188, kernel panic on 13.2';
        assert_script_run("zypper -n rm apparmor-abstractions");
    }
}

1;
# vim: set sw=4 et:
