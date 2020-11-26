# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validation module to check that partition is not activated.
# Covered scenarios:
# - Validate that hard disk encryption(LUKS) is not activated on the configured partitioning
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "installbasetest";
use scheduler 'get_test_suite_data';
use testapi;
use validate_encrypt_utils;
use Utils::Backends 'use_ssh_serial_console';

sub run {
    my $enc_disk_part = get_test_suite_data()->{enc_disk_part};
    select_console 'install-shell';
    verify_locked_encrypted_partition($enc_disk_part);
    select_console 'installation';
}

1;
