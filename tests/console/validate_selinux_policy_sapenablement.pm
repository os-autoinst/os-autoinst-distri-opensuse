# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate the presence of the selinux-policy-sapenablement package
# Maintainer: QE C <qe-c@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use version_utils qw(is_sle is_sles4sap);

sub run {
    die "Test suite designed to run only on SLES4SAP 16.0 and later"
      unless (is_sle('>=16.0') && get_var('FLAVOR', '') =~ /Minimal-VM-Cloud-sap/);

    validate_script_output(
        "rpm -q selinux-policy-sapenablement",
        sub {
            m/selinux-policy-sapenablement-/;
        },
        fail_message => "Package selinux-policy-sapenablement is not installed"
    );
}

1;
