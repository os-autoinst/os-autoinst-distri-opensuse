# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Small tests for MinimalVM that do not require a whole module for
#          themselves.
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use version_utils "is_sle";

my @failed_checks;

sub check_pcr_oracle_disabled {
    record_info(
        "check_pcr_oracle_disabled test",
        "pcr-oracle should not be installed on Encrypted images from SLES 16.1 onwards"
    );
    if (script_run("! rpm -q pcr-oracle")) {
        record_info(
            "pcr-oracle present",
            "pcr-oracle found but should not be installed",
            result => 'fail'
        );
        push @failed_checks, "check_pcr_oracle_disabled";
    }
}

sub run {
    my $checks_run = 0;

    # The pcr-oracle module must not be enabled in encrypted images 16.1+
    if (is_sle('>=16.1') && get_var('FLAVOR') =~ m/-encrypt/i) {
        check_pcr_oracle_disabled();
        $checks_run++;
    }

    if ($checks_run == 0) {
        record_info(
            "No checks",
            "Current image does not meet requirements for any small checks."
        );
    }
    elsif (@failed_checks) {
        die "The following checks failed: " . join(", ", @failed_checks);
    }
}

1;
