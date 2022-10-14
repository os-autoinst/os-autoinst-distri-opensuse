# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: revert or cleanup the configuration files and restart services
# Maintainer: Julie CAO <jcao@suse.com>
package cleanup_service;

use strict;
use warnings;
use base "virt_autotest_base";
use testapi;
use virt_autotest::utils qw(remove_vm);

sub run {
    #revert dns setting
    if (script_run('ls /etc/resolv.conf.orig') == 0) {
        script_run("mv /etc/resolv.conf.orig /etc/resolv.conf; mv /etc/named.conf.orig /etc/named.conf; mv /etc/ssh/ssh_config.orig /etc/ssh/ssh_config; mv /etc/dhcpd.conf.orig /etc/dhcpd.conf");
        script_run("sed -irn '/^nameserver 192\\.168\\.123\\.1/d' /etc/resolv.conf");
        script_run("rm /var/lib/named/testvirt.net.zone; rm /var/lib/named/123.168.192.zone");
    }

    #remove existing guests
    my $listed_guests = script_output("virsh list --all | sed -n '/^-/,\$p' | sed '1d;/Domain-0/d' | awk '{print \$2;}'", 30);
    remove_vm($_) foreach (split "\n", $listed_guests);

    #remove br123 and restart services
    assert_script_run "source /usr/share/qa/qa_test_virtualization/cleanup";
}

sub test_flags {
    return {fatal => 1};
}

1;
