# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Validate installed patterns in the SUT
# - Reads test data with expectations for patterns
# - Validates that installed patterns exactly match the expected ones
# Maintainer: QA SLE YaST <qa-sle-yast@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils qw(arrays_differ);

use repo_tools 'get_installed_patterns';
use scheduler 'get_test_suite_data';

sub run {
    my $test_data         = get_test_suite_data();
    my @expected_patterns = @{$test_data->{software}->{patterns}};

    select_console 'root-console';
    my @installed_patterns = get_installed_patterns();
    if (arrays_differ(\@expected_patterns, \@installed_patterns)) {
        die "Installed patterns do not match with the expected ones."
          . "\nExpected:\n" . join(', ', @expected_patterns)
          . "\nActual:\n" . join(', ', @installed_patterns);
    }
}

1;
