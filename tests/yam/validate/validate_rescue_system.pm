## Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Validate rescue system
# - Reads test data with needed tools and masked services
# - Validates that tools are available and services are masked
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    assert_screen('inst-console', 60);
    select_console 'install-shell';
    my $test_data = get_test_suite_data();
    my @needed_tools = @{$test_data->{tools}};
    foreach my $tool (@needed_tools) {
        assert_script_run("ls $tool", fail_message => "$tool is missing!");
    }
    my @masked_services = @{$test_data->{masked_services}};
    foreach my $service (@masked_services) {
        my $output = script_output("systemctl is-enabled $service", proceed_on_failure => 1);
        die "$service is not masked" unless $output =~ /masked/;
    }
}

1;
