# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: nmap iputils bind-utils
# Summary: This test prepares environment
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base "consoletest";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

sub run {
    my ($self) = @_;
    select_console("root-console");
    script_run("SUSEConnect -r " . get_var('SCC_REGCODE'), timeout => 420);
    assert_script_run "rm /etc/zypp/repos.d/SUSE_Maintenance* || true";
    assert_script_run "rm /etc/zypp/repos.d/TEST* || true";
    zypper_call '-t in nmap iputils bind-utils', exitcode => [0, 102, 103, 106];

    # Fill the current pairs of hostname & address into /etc/hosts file
    if (get_var("REGRESSION", '') =~ /vmware/) {
        foreach my $guest (keys %virt_autotest::common::guests) {
            my $ip = script_output(qq(ssh -o StrictHostKeyChecking=no root\@esxi7.qa.suse.cz "vim-cmd vmsvc/get.guest \\`vim-cmd vmsvc/getallvms | grep -w $guest|cut -d ' ' -f1\\`|grep -A 1 hostName|grep ipAddress|cut -d '\\"' -f2"));
            record_info("$guest: $ip");
            assert_script_run(qq(echo "$ip $guest" >> /etc/hosts));
        }
    } else {
        assert_script_run "echo \"\$(dig +short $virt_autotest::common::guests{$_}->{ip}) $_ # virtualization\" >> /etc/hosts" foreach (keys %virt_autotest::common::guests);
    }
    assert_script_run "cat /etc/hosts";
}
sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

