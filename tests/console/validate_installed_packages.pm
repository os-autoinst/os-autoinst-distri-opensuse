# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: validate packages in the SUT
# - Reads test data structure with expectations for packages
# - Validate that provided packages are installed or not
# Maintainer: QA SLE YaST <qa-sle-yast@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;

use repo_tools 'verify_software';
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data();
    my %packages  = %{$test_data->{software}->{packages}};
    # Variable to accumulate errors
    my $errors = '';
    # Validate packages
    for my $name (keys %packages) {
        $errors .= verify_software(name => $name,
            installed => $packages{$name}->{installed},
            available => 1);
    }
    # Fail in case of any unexpected results
    die "$errors" if $errors;
}

1;
