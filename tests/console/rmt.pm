# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add rmt configuration test
#    test installation and upgrade with rmt pattern, basic configuration via
#    rmt-wizard and validation with rmt-cli repos rmt-cli scc sync return value
# Maintainer: Jiawei Sun <jwsun@suse.com>

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
