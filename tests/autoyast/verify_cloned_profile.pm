# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validate if generated autoyast profile corresponds to the expected one
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

use strict;
use warnings;
use base 'basetest';
use testapi;
use scheduler;
use autoyast 'validate_autoyast_profile';

sub run {
    my $profile = get_test_suite_data()->{profile};
    validate_autoyast_profile($profile);
}

1;
