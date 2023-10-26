# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2021 SUSE LLC
#
# Summary: Print failed test info in xfstests
# Maintainer: Yong Sun <yosun@suse.com>

use 5.018;
use strict;
use warnings;
use base 'opensusebasetest';
use testapi;

sub run {
    my ($self, $args) = @_;
    record_info('INFO', "name: $args->{name}\ntest result: $args->{status}\ntime: $args->{time}\n");
    record_info('output', "$args->{output}");
    if ($args->{status} =~ /SOFTFAILED/) {
        $self->{result} = 'softfail';
        record_info('out.bad', "$args->{outbad}");
        record_info('full', "$args->{fullog}");
        record_info('dmesg', "$args->{dmesg}");
    }
    elsif ($args->{status} =~ /^FAILED/) {
        $self->{result} = 'fail';
        record_info('out.bad', "$args->{outbad}");
        record_info('full', "$args->{fullog}");
        record_info('dmesg', "$args->{dmesg}");
    }
    else {
        $self->{result} = 'skip';
    }
}

sub test_flags {
    return {no_rollback => 1, fatal => 0};
}

sub post_fail_hook {
    return;
}

1;
