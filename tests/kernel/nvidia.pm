# SUSE's openQA tests

# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: NVIDIA open source driver test
# Maintainer: Kernel QE <kernel-qa@suse.de>

use base 'opensusebasetest';
use testapi;
use utils;
use nvidia_utils;
use serial_terminal qw(select_serial_terminal);
use version_utils qw(is_sle is_sle_micro);

sub run
{
    my $self = shift;

    select_serial_terminal();

    nvidia_utils::install(variant => "cuda", reboot => 1);
    nvidia_utils::validate();
    nvidia_utils::validate_cuda() if is_sle;

    if (is_sle('15-SP6+') || is_sle_micro('6.0+')) {
        nvidia_utils::install(reboot => 1);
        nvidia_utils::validate();
    }
}

1;
