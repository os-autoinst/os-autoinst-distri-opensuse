# Copyright 2020-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Per TPM2 stack, we would like to add the tpm2-tools tests,
#          from sles15sp2, update tpm2.0-tools to the stable 4 release
#          this test module will cover sign and verify function.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64905, poo#105732, tc#1742297

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    my $self = shift;
    select_serial_terminal;

    my $tpm_suffix = '';
    $tpm_suffix = '-T tabrmd' if (get_var('QEMUTPM', 0) != 1 || get_var('QEMUTPM_VER', '') ne '2.0');

    # Sign and verify with the TPM using the endorsement hierarchy
    my $test_dir = "tpm2_tools_sign_verify";
    my $prim_ctx = "primary.ctx";
    my $rsa_priv = "rsa.priv";
    my $rsa_pub = "rsa.pub";
    my $msg_dat = "message.dat";
    my $rsa_ctx = "rsa.ctx";
    my $sig_rsa = "sig.rsa";
    assert_script_run "mkdir $test_dir";
    assert_script_run "cd $test_dir";
    assert_script_run "tpm2_createprimary -C e -c $prim_ctx $tpm_suffix";
    assert_script_run "tpm2_create -G rsa -u $rsa_pub -r $rsa_priv -C $prim_ctx $tpm_suffix";
    assert_script_run "tpm2_load -C $prim_ctx -u $rsa_pub -r $rsa_priv -c $rsa_ctx $tpm_suffix";
    assert_script_run "echo \"my message\" > $msg_dat";
    assert_script_run "tpm2_sign -c $rsa_ctx -g sha256 -o $sig_rsa $msg_dat $tpm_suffix";
    assert_script_run "tpm2_verifysignature -c $rsa_ctx -g sha256 -s $sig_rsa -m $msg_dat $tpm_suffix";
    assert_script_run "cd";
}

1;
