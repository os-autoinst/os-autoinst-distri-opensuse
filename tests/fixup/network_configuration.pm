# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Fixup network configuration when upgrading from openSUSE 13.2 (and lower)
#    openSUSE 13.2's (and earlier) systemd has broken rules for virtio-net,
#    not applying predictable names (despite being configured). A maintenance
#    update breaking networking names sounds worse than just accepting
#    that 13.2 -> TW breaks with virtio-net.
#
#    Since consoletest_setup is no longer the first thing running after the
#    system has been updated (it is now the check for applicable updates) this
#    fixup needed to be moved out of consoletest_setup in order to be started
#    earlier (again, asap, before anything wants to access the network)
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {

    select_console 'x11';
    # openSUSE 13.2's (and earlier) systemd has broken rules for virtio-net, not applying predictable names (despite being configured)
    # A maintenance update breaking networking names sounds worse than just accepting that 13.2 -> TW breaks with virtio-net
    # At this point, the system has been updated, but our network interface changed name (thus we lost network connection)
    my $command = "mv /etc/sysconfig/network/ifcfg-eth0 /etc/sysconfig/network/ifcfg-ens4; /usr/sbin/ifup ens4";

    if (get_var("DESKTOP") =~ /kde|gnome/) {
        x11_start_program('xterm');
        assert_script_sudo($command);
        send_key "alt-f4";
    }
    else {
        select_console 'root-console';
        assert_script_run($command);
    }
}

sub test_flags {
    return {milestone => 1};
}

1;
