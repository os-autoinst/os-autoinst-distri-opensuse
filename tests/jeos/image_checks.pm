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

sub check_pcr_oracle_absent {
    die "pcr-oracle must not be present on Encrypted images (bsc#1261611)" if (script_run("rpm -q pcr-oracle") == 0);
}

sub run {
    # PCR oracle must not be present on Encrypted Images from 16.1 onwards, see bsc#1261611
    check_pcr_oracle_absent() if (is_sle('>=16.1') && get_var('FLAVOR') =~ m/-encrypt/i);
}

1;
