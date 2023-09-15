# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: validate STIG rules checked by YaST during installation
#
# Maintainer: QE Security <none@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    my @errors;
    my $expected_stig_rules = get_test_suite_data()->{stig_rules_applied_by_yast};
    for my $rule (keys %$expected_stig_rules) {
        my $name = $expected_stig_rules->{$rule}{name};
        my $result = $expected_stig_rules->{$rule}{result};
        my $sles_ref = $expected_stig_rules->{$rule}{sles_ref};

        if (script_run("grep -A 1 -B 2 $rule /var/log/ssg-apply/*.out | grep 'Result.*$result'") != 0) {
            push @errors, "For STIG rule \"$name\" ($rule, $sles_ref), the expected result is '$result'";
        }
    }
    die "Evaluation of STIG rules after installation revealed that the Installer did not apply the following:\n" .
      join("\n", @errors) . "\nSee logs under /var/log/ssg-apply/*.out for further information\n" if @errors;
}

1;
