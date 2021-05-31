# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Handles Welcome dialog in YaST Firstboot Configuration.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_firstboot_basetest';
use strict;
use warnings;
use scheduler 'get_test_suite_data';

sub run {
    my $test_data            = get_test_suite_data()->{welcome};
    my $welcome              = $testapi::distri->get_firstboot_welcome();
    my $current_welcome_info = $welcome->collect_current_welcome_info();
    for my $line (@{$test_data->{text}}) {
        if ($current_welcome_info !~ $line) {
            die "Welcome message does not contain expected text '$line'";
        }
    }
    $welcome->proceed_with_current_configuration();
}

1;
