# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Use qa_test_multipath to test multipath over iscsi
# Maintainer: Petr Cervinka <pcervinka@suse.com>

use base 'user_regression';
use strict;
use warnings;
use testapi;
use utils;
use iscsi;

sub start_testrun {
    my $self = shift;

    zypper_call("in open-iscsi qa_test_multipath");

    systemctl 'start iscsid';
    systemctl 'start multipathd';

    # Set default variables for iscsi iqn and target
    my $iqn    = get_var("ISCSI_IQN",    "iqn.2016-02.de.openqa");
    my $target = get_var("ISCSI_TARGET", "10.0.2.1");

    # Connect to iscsi server and obtain wwid for multipath configuration
    iscsi_discovery $target;
    iscsi_login $iqn, $target;
    my $times = 10;
    ($times-- && sleep 1) while (script_run('multipathd -k"show multipaths status" | grep active') == 1 && $times);
    die 'multipath not ready even after waiting 10s' unless $times;
    my $wwid = script_output("multipathd -k\"show multipaths status\" | grep active | awk {'print \$1\'}");
    iscsi_logout $iqn, $target;

    # Configure test suite with proper iscsi iqn and target
    assert_script_run("sed -i '/^TARGET_DISK=.*/c\\TARGET_DISK=\"$iqn\"' /usr/share/qa/qa_test_multipath/data/vars");
    assert_script_run("sed -i '/^TARGET=.*/c\\TARGET=\"$target\"' /usr/share/qa/qa_test_multipath/data/vars");
    assert_script_run("cat /usr/share/qa/qa_test_multipath/data/vars");

    # Configure wwid in configuration files for each test
    my @config_files = qw(active_active active_passive path_checker_dio path_checker_tur);
    foreach my $config_file (@config_files) {
        assert_script_run "sed -i '/wwid .*/c\\wwid $wwid' /usr/share/qa/qa_test_multipath/data/$config_file";
        assert_script_run("cat /usr/share/qa/qa_test_multipath/data/$config_file");
    }

    $self->qaset_config();
    assert_script_run("/usr/share/qa/qaset/qaset reset");
    assert_script_run("/usr/share/qa/qaset/run/kernel-all-run.openqa");
}

sub test_run_list {
    return qw(_reboot_off sw_multipath);
}

sub junit_type {
    return 'user_regression';
}
1;

