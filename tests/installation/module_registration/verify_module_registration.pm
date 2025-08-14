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
use scheduler 'get_test_suite_data';
use utils 'arrays_subset';
use testapi;

sub run {
    my ($self) = @_;
    my %softfail_modules_data = (
        "sle-module-certifications" => "bsc#1214197 - no sle-module-certifications in 15sp6"
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
                select_console 'install-shell';
                my $error_msg = 'no sle-module-certifications in 15sp6';
                die $error_msg if $self->is_sles_in_rc_or_gm_phase();
                record_info('bsc#1214197', $error_msg);
                reset_consoles;
                select_console 'installation';
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
