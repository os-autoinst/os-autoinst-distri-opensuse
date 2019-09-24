# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# All of cases is based on the reference:
# https://documentation.suse.com/sles/15-SP1/single-html/SLES-admin/#id-1.3.3.6.13.6.13
#
# Tips: This testcase only runs on sles12 platforms.
#
# Summary: Setup SuSEfirewall2 and check if it works well
# - enable firewall
# - configure starup method interfaces, broadcast, services, and logging
# - check the results
# - remove the settings
# - stop firewall
# Maintainer: Shukui Liu <skliu@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;

use utils;


sub run {
    select_console 'root-console';

    #enable firewall
    zypper_call('in yast2-firewall', exitcode => [0, 102, 103, 106]);

    #change the startup setting and check it.
    assert_script_run 'yast firewall startup atboot';
    validate_script_output 'yast firewall startup show 2>&1', sub { m/Firewall is enabled in the boot process/ };
    assert_script_run 'yast firewall startup manual';
    validate_script_output 'yast firewall startup show 2>&1', sub { m/Firewall needs manual starting/ };

    assert_script_run 'yast firewall enable';
    systemctl 'is-active SuSEfirewall2.service';

    # list available zones.
    validate_script_output 'yast firewall zones list 2>&1', sub { m/INT/ and m/DMZ/ and m/EXT/ };

    #add interfaces and check it.
    assert_script_run 'yast firewall interfaces add interface=eth0 zone=EXT';
    validate_script_output 'yast firewall interfaces show 2>&1', sub { m/EXT\s+eth0/ };

    #removed the settings and check the results.
    assert_script_run 'yast firewall interfaces remove interface=eth0 zone=EXT';
    validate_script_output 'yast firewall interfaces show 2>&1', sub { $_ !~ m/EXT\s+eth0/ };

    #add broadcast ports and check it.
    assert_script_run 'yast firewall broadcast add zone=EXT port=ipp,233';
    validate_script_output 'yast firewall broadcast show 2>&1', sub { m/External Zone\s+ipp/ and m/External Zone\s+233/ };

    assert_script_run 'yast firewall broadcast remove zone=EXT port=ipp,233';
    validate_script_output 'yast firewall broadcast show 2>&1', sub { $_ !~ m/External Zone\s+ipp/ and $_ !~ m/External Zone\+233/ };

    #list services and make some changes, then check it.
    validate_script_output 'yast firewall services list 2>&1', sub { m/service:sshd/ };

    #Protection can only be set for internal zones.
    assert_script_run 'yast firewall services set protect=yes zone=INT';
    assert_script_run 'yast firewall services add service=service:sshd zone=EXT';
    validate_script_output 'yast firewall services show 2>&1', sub { m/EXT\s+service:sshd/ };

    assert_script_run 'yast firewall services remove service=service:sshd zone=EXT';
    validate_script_output 'yast firewall services show 2>&1', sub { $_ !~ m/EXT\s+sshd/ };

    #change the logging settings and check it.
    assert_script_run 'yast firewall logging set accepted=crit';
    assert_script_run 'yast firewall logging set logbroadcast=no zone=EXT';
    validate_script_output 'yast firewall logging show 2>&1', sub { m/Accepted\s+crit/ and m/External Zone\s+Logging disabled/ };

    # check the summary of the settings.
    validate_script_output 'yast firewall summary 2>&1', sub { m/Disable.+starting/ };

    #disable firewall
    assert_script_run 'yast firewall disable';

    # check if firewall service stops.
    die "yast failed to stop firewall service" unless systemctl('is-active SuSEfirewall2.service', ignore_failure => 1);

}

1;
