# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Unlocking LUKS volumes with TPM2
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#107488, tc#1769799, poo#112241

use strict;
use warnings;
use base qw(consoletest opensusebasetest);
use testapi;
use utils qw(quit_packagekit zypper_call);
use Utils::Backends 'is_pvm';
use power_action_utils 'power_action';


sub run {
    my $self = shift;

    select_console 'root-console';
    quit_packagekit;
    zypper_call('in expect');

    # Get the partition of the root volume
    my $luks2_part = script_output q(blkid | grep crypto_LUKS | awk -F: '{print $1}');
    my $luks2_volu = script_output q(cat /etc/crypttab | awk -F: '{print $1}');

    # Make sure the encryption type is LUKS2
    validate_script_output("cryptsetup status $luks2_volu", sub { m/LUKS2/ });

    # Find the entry for the LUKS2 volume in /etc/crypttab (it may appear referenced by its UUID) and add the tpm2-device= option
    assert_script_run q(sed -i 's/x-initrd.attach/x-initrd.attach,tpm2-device=auto/g' /etc/crypttab);

    # Regenerate the initrd.
    assert_script_run('dracut -f');

    # reboot to make new initrd effective
    power_action('reboot', textmode => 1, keepconsole => is_pvm());
    reconnect_mgmt_console() if is_pvm();
    $self->wait_boot();
    select_console 'root-console';

    # Enroll the LUKS2 volume with TPM device
    assert_script_run(
        "expect -c 'spawn systemd-cryptenroll --tpm2-device=auto $luks2_part; expect \"current passphrase*\"; send \"$testapi::password\\n\"; interact'"
    );

    # Set ENCRYPT=0 now, since we don't need unlock the disk via password
    set_var('ENCRYPT', 0);
}

1;
