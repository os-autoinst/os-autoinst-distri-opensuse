# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test IMA appraisal using digital signatures
# Maintainer: QE Security <none@suse.de>
# Tags: poo#53579, poo#100694, poo#102311

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use bootloader_setup qw(add_grub_cmdline_settings replace_grub_cmdline_settings tianocore_disable_secureboot);
use power_action_utils 'power_action';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $fstype = 'ext4';
    my $sample_app = '/usr/bin/yes';
    my $sample_cmd = 'yes --version';

    my $mok_priv = '/root/certs/key.asc';
    my $cert_der = '/root/certs/ima_cert.der';
    my $mok_pass = 'suse';

    add_grub_cmdline_settings("ima_appraise=fix", update_grub => 1);

    # We need re-enable the secureboot after removing "ima_appraise=fix" kernel parameter
    power_action("reboot", textmode => 1);
    $self->wait_grub(bootloader_time => 200);
    $self->tianocore_disable_secureboot;
    $self->wait_boot(textmode => 1);
    $self->select_serial_terminal;

    my @sign_cmd = (
        "/usr/bin/find / -fstype $fstype -type f -executable -uid 0 -exec evmctl -a sha256 ima_sign -p$mok_pass -k $mok_priv '{}' \\;",
"for D in /lib /lib64 /usr/lib /usr/lib64; do /usr/bin/find \"\$D\" -fstype $fstype -\\! -executable -type f -name '*.so*' -uid 0 -exec evmctl -a sha256 ima_sign -p$mok_pass -k $mok_priv '{}' \\; ; done",
        "/usr/bin/find /lib/modules -fstype $fstype -type f -name '*.ko' -uid 0 -exec evmctl -a sha256 ima_sign -p$mok_pass -k $mok_priv '{}' \\;",
        "/usr/bin/find /lib/firmware -fstype $fstype -type f -uid 0 -exec evmctl -a sha256 ima_sign -p$mok_pass -k $mok_priv '{}' \\;"
    );

    for my $s (@sign_cmd) {
        my $findret = script_output($s, 900, proceed_on_failure => 1);

        # Allow "No such file" message for the files in /proc because they are mutable
        my @finds = split /\n/, $findret;
        $_ =~ m/\/proc\/.*No such file|evm\/ima signature|hash\(sha256\)|^\w{530}$/ or die "Failed to create security.ima for $_" foreach (@finds);
    }

    validate_script_output "getfattr -m security.ima -d $sample_app", sub {
        # Base64 armored security.ima content (358 chars), we do not match the
        # last three ones here for simplicity
        m/security\.ima=[0-9a-zA-Z+\/]{355}/;
    };

    if (script_run("grep CONFIG_INTEGRITY_TRUSTED_KEYRING=y /boot/config-`uname -r`") == 0) {
        record_soft_failure("bsc#1157432 for SLE15SP2+: CA could not be loaded into the .ima or .evm keyring");
    }
    else {
        # Prepare mok ceritificate file
        assert_script_run "mkdir -p /etc/keys/ima";
        assert_script_run "cp $cert_der /etc/keys/ima/";

        assert_script_run "wget --quiet " . data_url("ima/ima_appraisal_ds_policy" . " -O /etc/sysconfig/ima-policy");

        replace_grub_cmdline_settings('ima_appraise=fix', '', update_grub => 1);

        power_action('reboot', textmode => 1);
        $self->wait_grub(bootloader_time => 200);
        $self->tianocore_disable_secureboot('re_enable');
        $self->wait_boot(textmode => 1);
        $self->select_serial_terminal;
        assert_script_run "dmesg | grep IMA:.*completed";

        # Remove security.ima attribute manually, and verify it is empty
        assert_script_run "setfattr -x security.ima $sample_app";
        validate_script_output "getfattr -m security.ima -d $sample_app", sub { m/^$/ };

        my $ret = script_output($sample_cmd, 30, proceed_on_failure => 1);
        die "$sample_app should not have permission to run" if ($ret !~ "\Q$sample_app\E: *Permission denied");

    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
