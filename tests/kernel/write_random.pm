# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Write 100M of random data
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>
#
# Used for stressing OpenQA milestones, see lib/main_ltp.pm.

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi qw(is_serial_terminal :DEFAULT);
use utils;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);
use File::Basename 'basename';
use serial_terminal;
require bmwqemu;

sub run {
    my ($self) = @_;

    assert_script_run('touch /tmp/random');
    assert_script_run('dd if=/dev/urandom of=/tmp/random bs=4096 count=25600');
}

sub test_flags {
    return {
        fatal     => 1,
        milestone => 1,
    };
}


1;
