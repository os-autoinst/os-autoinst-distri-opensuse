# Copyright 2020-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Per TPM2 stack, we would like to add the tpm2-tools tests,
#          from sles15sp2, update tpm2.0-tools to the stable 4 release
#          this test module will cover auth tests.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64905, poo#105732, tc#1742297

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    # Modify authorization for a loadable transient object
    my $test_dir = "tpm2_tools_auth";
    my $prim_ctx = "prim.ctx";
    my $key_priv = "key.priv";
    my $key_pub = "key.pub";
    my $key_name = "key.name";
    my $ket_ctx = "key.ctx";

    my $tpm_suffix = '';
    $tpm_suffix = '-T tabrmd' if (get_var('QEMUTPM', 0) != 1 || get_var('QEMUTPM_VER', '') ne '2.0');

    assert_script_run "mkdir $test_dir";
    assert_script_run "cd $test_dir";
    assert_script_run "tpm2_createprimary -Q -C o -c $prim_ctx $tpm_suffix";
    assert_script_run "tpm2_create -Q -g sha256 -G aes -u $key_pub -r $key_priv -C $prim_ctx $tpm_suffix";
    assert_script_run "tpm2_load -C $prim_ctx -u $key_pub -r $key_priv -n $key_name -c $ket_ctx $tpm_suffix";
    assert_script_run "tpm2_changeauth -c $ket_ctx -C $prim_ctx -r $key_priv newkeyauth $tpm_suffix";
    assert_script_run "tpm2_clear $tpm_suffix";

    # Modify authorization for a NV Index Requires Extended Session Support
    my $ses_ctx = "session.ctx";
    assert_script_run "tpm2_startauthsession -S $ses_ctx $tpm_suffix";
    assert_script_run "tpm2_policycommandcode -S $ses_ctx -L policy.nvchange TPM2_CC_NV_ChangeAuth $tpm_suffix";

    # TPM2_CC_NV_ChangeAuth
    my $nv_val = "0x1500015";
    assert_script_run "tpm2_flushcontext $ses_ctx $tpm_suffix";
    assert_script_run "tpm2_nvdefine $nv_val -C o -s 32 -a \"authread|authwrite\" -L policy.nvchange $tpm_suffix";
    assert_script_run "tpm2_startauthsession --policy-session -S $ses_ctx $tpm_suffix";
    assert_script_run "tpm2_policycommandcode -S $ses_ctx -L policy.nvchange TPM2_CC_NV_ChangeAuth $tpm_suffix";
    assert_script_run "tpm2_changeauth -p session:$ses_ctx -c $nv_val newindexauth $tpm_suffix";
    assert_script_run "tpm2_clear $tpm_suffix";

    # Tpm2_changeauth - Configures authorization values for the various hierarchies, NV indices
    # Set owner, endorsement and lockout authorizations to $new_pass
    my $new_pass = "newpass";
    my $newer_pass = "newerpass";
    assert_script_run "tpm2_changeauth -c owner $new_pass $tpm_suffix";
    assert_script_run "tpm2_changeauth -c endorsement $new_pass $tpm_suffix";
    assert_script_run "tpm2_changeauth -c lockout $new_pass $tpm_suffix";

    # Change owner, endorsement and lockout authorizations
    assert_script_run "tpm2_changeauth -c o -p $new_pass $newer_pass $tpm_suffix";
    assert_script_run "tpm2_changeauth -c e -p $new_pass $newer_pass $tpm_suffix";
    assert_script_run "tpm2_changeauth -c l -p $new_pass $newer_pass $tpm_suffix";
    assert_script_run "cd";
}

1;
