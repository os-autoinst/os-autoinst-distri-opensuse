# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: TPM2 scenario where boot components are updated, failing LUKS key unsealing.
# Calculate the new PCRs and updates the signature in the sealed key with command
# `fdectl tpm-authorize`.
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#134984

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use transactional 'process_reboot';

sub run {
    select_console('root-console');

    # Modify boot component
    assert_script_run(
        'sed -i \'s/set btrfs_relative_path="yes"/set  btrfs_relative_path="yes"/\' '
          . '/boot/efi/EFI/*/grub.cfg');

    # Expect after reboot passphrase prompt due to unsealing of the LUKS key should fail
    process_reboot(trigger => 1, expected_passphrase => 1);

    # Compute/install new policy after changes using authorized policies
    assert_script_run('fdectl tpm-authorize');

    # processing of reboot should end up in grub menu with TPM2 unsealing the key back again
    process_reboot(trigger => 1);
}

1;
