# Copyright 2020-2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Verify TPM2 asymmetric sign/verify, persistent key reuse and PCR policy signing
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64905, poo#105732, poo#202523, tc#1742297

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    my $tpm_suffix = '';
    $tpm_suffix = '-T tabrmd' if (get_var('QEMUTPM', 0) != 1 || get_var('QEMUTPM_VER', '') ne '2.0');

    my $wd = "tpm2_tools_sign_verify";
    assert_script_run "mkdir -p $wd && cd $wd";

    # --- RSA sign/verify ---
    record_info('RSA', 'RSA signing and verification');
    assert_script_run "tpm2_createprimary -C e -c primary.ctx $tpm_suffix";
    assert_script_run "tpm2_create -G rsa -u rsa.pub -r rsa.priv -C primary.ctx $tpm_suffix";
    assert_script_run "tpm2_load -C primary.ctx -u rsa.pub -r rsa.priv -c rsa.ctx $tpm_suffix";
    assert_script_run "echo 'test message' > msg.dat";
    assert_script_run "tpm2_sign -c rsa.ctx -g sha256 -o sig.rsa msg.dat $tpm_suffix";
    assert_script_run "tpm2_verifysignature -c rsa.ctx -g sha256 -s sig.rsa -m msg.dat $tpm_suffix";

    # --- ECC sign/verify ---
    record_info('ECC', 'ECC signing and verification');
    assert_script_run "tpm2_create -G ecc -u ecc.pub -r ecc.priv -C primary.ctx $tpm_suffix";
    assert_script_run "tpm2_load -C primary.ctx -u ecc.pub -r ecc.priv -c ecc.ctx $tpm_suffix";
    assert_script_run "tpm2_sign -c ecc.ctx -g sha256 -o sig.ecc msg.dat $tpm_suffix";
    assert_script_run "tpm2_verifysignature -c ecc.ctx -g sha256 -s sig.ecc -m msg.dat $tpm_suffix";

    # --- Persistent handle test ---
    record_info('PERSIST', 'Persistent signing key reuse');
    assert_script_run "tpm2_evictcontrol -C o -c rsa.ctx 0x81010003 $tpm_suffix";
    validate_script_output "tpm2_readpublic -c 0x81010003 $tpm_suffix", sub { /type:.*rsa/s };
    assert_script_run "tpm2_sign -c 0x81010003 -g sha256 -o sig.persist msg.dat $tpm_suffix";
    assert_script_run "tpm2_verifysignature -c 0x81010003 -g sha256 -s sig.persist -m msg.dat $tpm_suffix";

    # --- PCR-bound key test ---
    record_info('PCR', 'PCR-bound key signing');
    assert_script_run "tpm2_pcrread sha256:7 $tpm_suffix -o pcr.bin";
    assert_script_run "tpm2_createpolicy --policy-pcr -l sha256:7 -f pcr.bin -L policy.digest $tpm_suffix";
    assert_script_run "tpm2_create -G rsa -u pcr.pub -r pcr.priv -C primary.ctx -L policy.digest $tpm_suffix";
    assert_script_run "tpm2_load -C primary.ctx -u pcr.pub -r pcr.priv -c pcr.ctx $tpm_suffix";
    assert_script_run "tpm2_startauthsession --policy-session -S session.ctx $tpm_suffix";
    assert_script_run "tpm2_policypcr -S session.ctx -l sha256:7 -f pcr.bin $tpm_suffix";
    assert_script_run "tpm2_sign -c pcr.ctx -g sha256 -o sig.pcr -p session:session.ctx msg.dat $tpm_suffix";
    assert_script_run "tpm2_flushcontext session.ctx $tpm_suffix";
    assert_script_run "tpm2_verifysignature -c pcr.ctx -g sha256 -s sig.pcr -m msg.dat $tpm_suffix";

    # --- Cleanup ---
    record_info('CLEANUP', 'Clearing persistent handles and context');
    script_run "tpm2_evictcontrol -C o -c 0x81010003 $tpm_suffix";
    script_run "cd / && rm -rf $wd";
}

1;
