# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: server hostname setup and check
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "consoletest";
use strict;
use testapi;

sub run() {
    select_console 'root-console';

    my $hostname = get_var("HOSTNAME", 'susetest');
    assert_script_run "hostnamectl set-hostname $hostname";
    assert_script_run "hostnamectl status | grep $hostname";
    assert_script_run "hostname | grep $hostname";
    script_run "systemctl status network.service";
    save_screenshot;
    # Do not set hostname from DHCP for a while, otherwise hostname is re-set to transient
    # hostname on network restart, where user-mode networking is not present (i.e. brigged networks).
    assert_script_run("sed -ie '/DHCLIENT_SET_HOSTNAME=/s/=.*/=\"no\"/' /etc/sysconfig/network/dhcp");
    # DHCP/DNS don't know about the changed hostname, a new DHCP request should be send
    # to update dynamic DNS. yast2-network module restarts network.service via `yast2 lan`.
    assert_script_run "if systemctl -q is-active network.service; then systemctl reload-or-restart network.service; fi";
    script_run "systemctl status network.service";
    save_screenshot;
    assert_script_run("sed -ie '/DHCLIENT_SET_HOSTNAME=/s/=.*/=\"yes\"/' /etc/sysconfig/network/dhcp");
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
