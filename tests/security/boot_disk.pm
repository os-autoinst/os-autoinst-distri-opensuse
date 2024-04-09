# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC

# Summary: boot disk using the right moodules
# Maintainer: QE Security <none@suse.de>

use strict;
use warnings;
use base "installbasetest";
use utils;
use Utils::Architectures;
use Utils::Backends;
use security_boot_utils;
use version_utils qw(is_sle is_sle_micro);
use testapi;

sub run {
    my ($self) = shift;

    if (boot_has_no_video) {
        $self->boot_encrypt_no_video;
    } else {
        my $timeout = get_var('BOOTLOADER_TIMEOUT', 200);
        # Increase timeout on ipmi bare metal backend, firmware initialization takes a lot of time
        $timeout += 300 if is_ipmi;

        # Booting of encrypted disk needs additional time too.
        $timeout += 60 if get_var('ENCRYPT');

        # Add additional 120s if the test suite is pvm
        $timeout += 120 if is_pvm;

        my $enable_root_ssh = (is_sle_micro('>=6.0') && is_s390x) ? 1 : 0;
        $self->wait_boot(bootloader_time => $timeout, enable_root_ssh => $enable_root_ssh);
    }
}

sub test_flags {
    # add milestone flag to save setup in lastgood VM snapshot
    return {fatal => 1, milestone => 1};
}

1;
