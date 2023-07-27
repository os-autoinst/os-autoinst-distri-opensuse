# SLE15 migration tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Record the installed rpm list before conducting migration
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi qw(assert_script_run upload_logs);

sub run {
    assert_script_run 'rpm -qa > /tmp/rpm-qa.txt';
    upload_logs '/tmp/rpm-qa.txt';
}

1;

