# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Encryption and decryption tests for the TPM2 stack
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64905, poo#105732, tc#1742297, poo#195086

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    my $use_tabrmd = get_var('QEMUTPM', 0) != 1 || get_var('QEMUTPM_VER', '') ne '2.0';
    my $tpm_suffix = $use_tabrmd ? '-T tabrmd' : '';
    my $test_dir = "tpm2_tools_encrypt";
    assert_script_run "mkdir -p $test_dir";

    # Write/Read data to/from a Non-Volatile (NV) index
    my $test_file = "$test_dir/nv.test_w";
    assert_script_run "tpm2_nvdefine -Q  1 -C o -s 32 -a \"ownerread|policywrite|ownerwrite\" $tpm_suffix";
    validate_script_output "tpm2_nvreadpublic $tpm_suffix", sub { m/0x1000001/ };
    assert_script_run "echo \"please123abc\" > $test_file";
    assert_script_run "tpm2_nvwrite -Q  1 -C o -i $test_file $tpm_suffix";
    assert_script_run "tpm2_nvread -Q  1 -C o -s 32 -o 0 $tpm_suffix";

    # tpm2_nvundefine(1) - Delete a Non-Volatile (NV) index
    assert_script_run "tpm2_nvundefine -Q  1 -C o $tpm_suffix";
    validate_script_output "tpm2_nvreadpublic $tpm_suffix | wc -l", sub { m/0/ };

    # Create an ECC primary object
    my $context_out = "$test_dir/context.out";
    my $key_priv = "$test_dir/key.priv";
    my $key_pub = "$test_dir/key.pub";
    my $key_ctx = "$test_dir/key.ctx";

    assert_script_run "tpm2_createprimary -C o -g sha256 -G ecc -c $context_out $tpm_suffix";

    # tpm2_create(1) - Create a child object
    assert_script_run "tpm2_create -C $context_out -G rsa2048:rsaes -u $key_pub -r $key_priv $tpm_suffix";

    # tpm2_load(1) - Load both the private and public portions of an object into the TPM
    assert_script_run "tpm2_load  -C $context_out -u $key_pub -r $key_priv -c $key_ctx $tpm_suffix";

    # Encrypt using RSA
    my $msg_dat = "$test_dir/msg.dat";
    my $msg_enc = "$test_dir/msg.enc";
    assert_script_run "echo \"my message\" > $msg_dat";
    assert_script_run "tpm2_rsaencrypt -c $key_ctx -o $msg_enc $msg_dat $tpm_suffix";

    # Decrypt using RSA
    my $msg_ptext = "$test_dir/msg.ptext";
    assert_script_run "tpm2_rsadecrypt -c $key_ctx -o $msg_ptext $msg_enc $tpm_suffix";
    assert_script_run "diff $msg_dat $msg_ptext";
}

1;
