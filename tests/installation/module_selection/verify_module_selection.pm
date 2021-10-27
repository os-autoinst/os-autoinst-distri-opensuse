# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify that the expected modules appear on the module list
#          during graphical installation and that only default ones
#          are selected.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use scheduler 'get_test_suite_data';
use utils 'arrays_differ';

sub run {
    my @expected_modules = @{get_test_suite_data()->{modules}};
    my @modules = @{$testapi::distri->get_module_selection()->get_modules()};
    die "Modules do not match with the expected ones."
      . "\nExpected:\n" . join(', ', @expected_modules)
      . "\nActual:\n" . join(', ', @modules)
      if arrays_differ(\@expected_modules, \@modules);
    my @expected_selected_modules = @{get_test_suite_data()->{selected_modules}};
    my @selected_modules = @{$testapi::distri->get_module_selection()->get_selected_modules()};
    die "Selected modules are not the default ones"
      . "\nExpected:\n" . join(', ', @expected_selected_modules)
      . "\nActual:\n" . join(', ', @selected_modules)
      if arrays_differ(\@expected_selected_modules, \@selected_modules);
}

1;
