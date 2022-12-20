# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: remove kernel-default and install kernel-rt
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call);

sub run {
    select_serial_terminal;

    zypper_call('rm kernel-default');
    zypper_call('in kernel-rt');
}

sub test_flags {
    return {fatal => 1};
}

1;
