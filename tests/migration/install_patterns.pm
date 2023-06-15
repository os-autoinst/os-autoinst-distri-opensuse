# SLE15 migration tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install patterns for allpatterns cases before conducting migration
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use migration;
use y2_base;

sub run {
    select_console 'root-console';
    install_patterns() if (get_var('PATTERNS'));

    # Record the installed rpm list
    assert_script_run 'rpm -qa > /tmp/rpm-qa.txt';
    upload_logs '/tmp/rpm-qa.txt';
}

1;
