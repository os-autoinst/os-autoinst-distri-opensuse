# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Handles Users dialog in YaST Firstboot Configuration.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_firstboot_basetest';
use strict;
use warnings;
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data()->{users};
    my $user_info = {%{$test_data}, (password => $testapi::password)};
    $testapi::distri->get_local_user()
      ->create_new_user_with_simple_password($user_info);
}

1;
