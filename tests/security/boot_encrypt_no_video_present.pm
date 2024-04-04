# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC

# Summary: Unlock encrypted partitions during bootup after the bootloader
#   passed, e.g. from plymouth.
# Maintainer: QE Security <none@suse.de>

use strict;
use warnings;
use base "installbasetest";
use utils;
use testapi;

sub run {
    # used by aarch64 on 15-SP5 QR (https://progress.opensuse.org/issues/156655)
    assert_screen 'encrypted-disk-no-video';
    wait_serial("Please enter passphrase for disk.*");
    type_string_slow("$testapi::password");
    send_key 'ret';
    wait_still_screen 15;
}

1;
