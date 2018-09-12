# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: guest_installation_run: This test is used to verify if different products can be installed successfully as guest on specify host.
# Maintainer: alice <xlai@suse.com>

use base "virt_autotest_base";
use strict;
use warnings;
use testapi;
use virt_utils;

sub get_script_run {
    my $prd_version = script_output("cat /etc/issue");
    my $pre_test_cmd;
    if ($prd_version =~ m/SUSE Linux Enterprise Server 11/) {
        $pre_test_cmd = "/usr/share/qa/tools/test_virtualization-standalone-run";
    }
    else {
        $pre_test_cmd = "/usr/share/qa/tools/test_virtualization-virt_install_withopt-run";
    }
    # testsuite setting pre-handling for no service pack products
    handle_sp_in_settings_with_fcs("GUEST_PATTERN");
    my $guest_pattern = get_var('GUEST_PATTERN', 'sles-12-sp2-64-[p|f]v-def-net');
    my $parallel_num  = get_var("PARALLEL_NUM",  "2");
    $pre_test_cmd = $pre_test_cmd . " -f " . $guest_pattern . " -n " . $parallel_num . " -r ";

    return $pre_test_cmd;
}

sub analyzeResult {
    my ($self, $text) = @_;
    my $result;
    $text =~ /Test in progress(.*)Test run complete/s;
    my $rough_result = $1;
    foreach (split("\n", $rough_result)) {
        if ($_ =~ /(\S+)\s+\.{3}\s+\.{3}\s+(PASSED|FAILED|SKIPPED|TIMEOUT)\s+\((\S+)\)/g) {
            $result->{$1}{status} = $2;
            $result->{$1}{time}   = $3;
        }
    }
    return $result;
}

sub run {
    my $self = shift;

    $self->{"product_tested_on"} = "SLES-12-SP2";
    $self->{"product_name"}      = "GuestIn_stallation";
    $self->{"package_name"}      = "Guest Installation Test";

    $self->run_test(7600, "", "yes", "yes", "/var/log/qa/", "guest-installation-logs");
}

1;

