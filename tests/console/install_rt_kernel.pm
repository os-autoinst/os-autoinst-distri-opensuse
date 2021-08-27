# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: remove kernel-default and install kernal-rt
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils qw(zypper_call);

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    zypper_call('rm kernel-default');
    zypper_call('in kernel-rt');
}

sub test_flags {
    return {fatal => 1};
}

1;
