# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Unlocking LUKS volumes with TPM2
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#107488, tc#1769799, poo#112241

use base qw(consoletest opensusebasetest);
use testapi;
use utils qw(quit_packagekit zypper_call);
use Utils::Backends 'is_pvm';
use power_action_utils 'power_action';
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_sle is_bootloader_grub2_bls);


sub run {
    my $self = shift;

    select_serial_terminal;
    quit_packagekit;
    zypper_call('in expect jq');

    # Get all usable LUKS volumes
    my @luks_volumes = split /\n/, script_output q(awk '!/^#/ && NF && /x-initrd.attach/ {print $1}' /etc/crypttab);

    # Verify all volumes are LUKS2
    for my $volume (@luks_volumes) {
        my $dev = script_output(qq(cryptsetup status $volume | awk '/device:/ {print \$2}'));
        record_info("$volume -> $dev");
        assert_script_run(qq(cryptsetup isLuks $dev));
    }


    # Find the entry for the LUKS2 volume in /etc/crypttab (it may appear referenced by its UUID) and add the tpm2-device= option
    assert_script_run q(sed -i 's/x-initrd.attach/x-initrd.attach,tpm2-device=auto/g' /etc/crypttab);

    # Regenerate the initrd.
    my $initrd_regenerate_cmd = is_bootloader_grub2_bls ? 'sdbootutil mkinitrd' : 'dracut -f';
    assert_script_run($initrd_regenerate_cmd);

    # reboot to make new initrd effective
    power_action('reboot', textmode => 1, keepconsole => is_pvm());
    reconnect_mgmt_console() if is_pvm();
    $self->wait_boot();
    select_serial_terminal;

    # Enroll the LUKS2 volumes with TPM device
    for my $volume (@luks_volumes) {
        my $dev = script_output(qq(cryptsetup status $volume | awk '/device:/ {print \$2}'));
        record_info('TPM2 enrollment', "Enrolling $dev with TPM2");
        assert_script_run(
            "expect -c 'spawn systemd-cryptenroll --tpm2-device=auto $dev; expect \"current passphrase*\"; send \"$testapi::password\\n\"; interact'"
        );
    }

    # Set ENCRYPT=0 now, since we don't need unlock the disk via password
    set_var('ENCRYPT', 0) unless is_sle('>=16');

    # Reboot again to verify TPM2 unlock works
    power_action('reboot', textmode => 1, keepconsole => is_pvm());
    reconnect_mgmt_console() if is_pvm();
    $self->wait_boot();
    select_serial_terminal;

    for my $volume (@luks_volumes) {
        my $dev = script_output(qq(cryptsetup status $volume | awk '/device:/ {print \$2}'));
        assert_script_run(qq(cryptsetup luksDump --dump-json-metadata $dev  | jq -e '.tokens[] | select(.type=="systemd-tpm2")'));
    }
}

1;
