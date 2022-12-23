# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate if generated autoyast profile corresponds to the expected one
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
