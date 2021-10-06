# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: RT preempt test
# Maintainer: mkravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils qw(zypper_call);

# Run preempt test
sub run {
    (my $version = get_var('VERSION')) =~ s/-/_/g;
    zypper_call "ar --refresh --no-gpgcheck http://download.suse.de/ibs/home:/mloviska/SUSE_SLE_$version preempt_temp_repo";
    zypper_call "install preempt-test";
    assert_script_run "preempt-test | tee ~/preempt.out";
    assert_script_run "grep \'Test PASSED\' ~/preempt.out && rm -f ~/preempt.out";
}

1;
