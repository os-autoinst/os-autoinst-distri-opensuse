# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rmt-server mariadb yast2-rmt
# Summary: Add rmt configuration test
#    test installation and upgrade with rmt pattern, basic configuration via
#    rmt-wizard and validation with rmt-cli repos rmt-cli scc sync return value
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use repo_tools;
use version_utils;

sub run {
    select_console('root-console');

    # We need ensure the firewalld is enabled for the requirement of RMT wizard
    assert_script_run('systemctl enable firewalld');
    # No need to config rmt if the system upgraded from SLE12SPx with SMT
    rmt_wizard unless (is_upgrade && (get_var('HDD_1', '') =~ /smt/));
    # mirror and sync a base repo from SCC
    rmt_mirror_repo();
}

sub test_flags {
    return {fatal => 1};
}

1;
