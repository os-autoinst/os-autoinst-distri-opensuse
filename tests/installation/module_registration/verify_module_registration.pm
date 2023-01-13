# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify that the expected modules appear on the module list
#          during graphical installation and that only default ones
#          are selected.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use scheduler 'get_test_suite_data';
use utils 'arrays_subset';
use testapi;

sub run {
    my %softfail_modules_data = (
        PackageHub => "bsc#1202416 - packagehub cannot work at sles15sp5",
        "sle-module-NVIDIA-compute" => "bsc#1204611 - no sle-module-NVIDIA-compute in 15sp5",
        "sle-module-certifications" => "bsc#1204612 - no sle-module-certifications in 15sp5",
    );

    my @softfail_modules = keys %softfail_modules_data;
    my @expected_modules = @{get_test_suite_data()->{modules}};
    my @modules = @{$testapi::distri->get_module_registration()->get_modules()};
    my @diff = arrays_subset(\@expected_modules, \@modules);
    my @diff2 = arrays_subset(\@diff, \@softfail_modules);
    if (scalar @diff > 0) {
        if (scalar @diff2 > 0) {
            die "Modules do not match with the expected ones."
              . "\nExpected:\n"
              . join(', ', @expected_modules)
              . "\nActual:\n"
              . join(', ', @modules)
              . "\nFailed modules:\n"
              . join(', ', @diff2);
        }
        else {
            foreach (@diff) {
                # Hack prefix string "BUG#0#BUG" for workaround CI check of record_soft_failure
                record_soft_failure("BUG#0#BUG:" . $softfail_modules_data{$_});
            }
        }
    }

    my @expected_registered_modules = @{get_test_suite_data()->{registered_modules}};
    my @registered_modules = @{$testapi::distri->get_module_registration()->get_registered_modules()};
    @diff = arrays_subset(\@expected_registered_modules, \@registered_modules);
    @diff2 = arrays_subset(\@diff, \@softfail_modules);
    if (scalar @diff > 0) {
        if (scalar @diff2 > 0) {
            die "Selected modules are not the default ones"
              . "\nExpected:\n"
              . join(', ', @expected_registered_modules)
              . "\nActual:\n"
              . join(', ', @registered_modules)
              . "\nFailed modules:\n"
              . join(', ', @diff2);
        }
        else {
            foreach (@diff) {
                # Hack prefix string "BUG#0#BUG" for workaround CI check of record_soft_failure
                record_soft_failure("BUG#0#BUG:" . $softfail_modules_data{$_});
            }
        }
    }
}

1;
