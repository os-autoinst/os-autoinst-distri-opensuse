# SUSE's openQA tests

# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: NVIDIA open source driver test
# Maintainer: Kernel QE <kernel-qa@suse.de>

use base 'opensusebasetest';
use strict;
use testapi;
use utils;
use warnings;
use nvidia_utils;
use serial_terminal qw(select_serial_terminal);

sub run
{
    my $self = shift;

    select_serial_terminal();

    nvidia_utils::install(variant => "cuda", reboot => 1);
    nvidia_utils::validate();

    nvidia_utils::install(reboot => 1);
    nvidia_utils::validate();
}

1;
