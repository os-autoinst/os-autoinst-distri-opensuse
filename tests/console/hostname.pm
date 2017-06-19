# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
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

    my $hostname = get_var('HOSTNAME', 'susetest');
    my $domain = check_var('DISTRI', 'opensuse') ? 'openqa.opensuse.org' : 'openqa.suse.de';
    # create entry in /etc/hosts for FQDN hostname
    assert_script_run 'interface=`awk \'{print$6}\' /proc/net/arp|uniq|tail -n1`';
    assert_script_run 'ip=`ip a|grep $interface|grep inet|awk -F\' *|/\' \'{print$3}\'`';
    assert_script_run "echo \"\$ip $hostname.$domain $hostname\" >> /etc/hosts";
    assert_script_run 'cat /etc/hosts';
    assert_script_run "hostnamectl set-hostname $hostname";
    assert_script_run "hostnamectl status|grep $hostname";
    assert_script_run "hostname -f|grep $hostname";
    # if you change hostname using `hostnamectl set-hostname`, then `hostname -f` will fail with "hostname: Name or service not known"
    # also DHCP/DNS don't know about the changed hostname, you need to send a new DHCP request to update dynamic DNS
    # yast2-network module does "NetworkService.ReloadOrRestart if Stage.normal || !Linuxrc.usessh" if hostname is changed via `yast2 lan`
    script_run "systemctl --no-pager status network.service";
    save_screenshot;
    assert_script_run "if systemctl -q is-active network.service; then systemctl reload-or-restart network.service; fi";
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
