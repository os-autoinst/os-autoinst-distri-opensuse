# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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

        # openSUSE 13.2's systemd has broken rules for virtio-net, not applying predictable names (despite being configured)
        # A maintenance update breaking networking names sounds worse than just accepting that 13.2 -> TW breaks
        # After dup'ing, the naming starts working, but our network interface changes name (thus we lose network connection)
        if (check_var('HDDVERSION', "openSUSE-13.2")) {    # copy eth0 network config to ens4
            script_run("cp /etc/sysconfig/network/ifcfg-eth0 /etc/sysconfig/network/ifcfg-ens4");
        }

        # The CD was ejected in the bootloader test
        type_string("/sbin/reboot\n");

        reset_consoles;
        wait_boot textmode => 1;

        select_console('root-console');
    }

    $self->set_standard_prompt();

    # Disable console screensaver
    assert_script_run("setterm -blank 0");

    # bnc#949188. kernel panic on 13.2
    if (get_var('HDD_1', '') =~ /opensuse-13\.2/) {
        record_soft_failure;
        assert_script_run("zypper -n rm apparmor-abstractions");
    }
}

1;
# vim: set sw=4 et:
