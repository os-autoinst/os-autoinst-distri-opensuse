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
    select_console 'root-console';

    my $hostname = get_var("HOSTNAME", 'susetest');
    assert_script_run "hostnamectl set-hostname $hostname", 20;

    script_run "hostnamectl status";
    assert_screen("hostnamectl_status_$hostname");

    script_run "hostname";
    assert_screen("hostname-$hostname");
    # if you change hostname using `hostnamectl set-hostname`, then `hostname -f` will fail with "hostname: Name or service not known"
    # also DHCP/DNS don't know about the changed hostname, you need to send a new DHCP request to update dynamic DNS
    # yast2-network module does "NetworkService.ReloadOrRestart if Stage.normal || !Linuxrc.usessh" if hostname is changed via `yast2 lan`
    assert_script_run "systemctl -q is-active network.service && systemctl reload-or-restart network.service";
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
