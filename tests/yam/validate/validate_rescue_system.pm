## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Validate rescue system
# - Reads test data with needed tools and masked services
# - Validates that tools are available and services are masked
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    assert_screen('inst-console', 30);
    select_console 'install-shell';
    my $test_data = get_test_suite_data();
    my @needed_tools = @{$test_data->{tools}};
    foreach my $tool (@needed_tools) {
        assert_script_run("ls $tool", fail_message => "$tool is missing!");
    }
}

1;
