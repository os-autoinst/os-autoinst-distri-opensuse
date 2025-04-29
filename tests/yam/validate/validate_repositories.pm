# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the repositories are set properly by Agama.
# Check expected repositories against test data and they should be enabled.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':assert';
use utils;

sub run {
    select_console 'root-console';
    my @expected_repositories = @{get_test_suite_data()->{repositories}};
    my $repositories = script_output("zypper repos --show-enabled-only");
    diag("Host repository info: \n$repositories\n");
    for (@expected_repositories) {
        $repositories =~ $_ ? diag("Repository $_ is enabled.") : die "Repostory $_ is not enabled on the host";
    }
}

1;
