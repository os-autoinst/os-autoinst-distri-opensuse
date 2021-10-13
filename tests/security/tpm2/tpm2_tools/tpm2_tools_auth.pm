# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Per TPM2 stack, we would like to add the tpm2-tools tests,
#          from sles15sp2, update tpm2.0-tools to the stable 4 release
#          this test module will cover auth tests.
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#64905, tc#1742297

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Modify authorization for a loadable transient object
    my $test_dir = "tpm2_tools_auth";
    my $prim_ctx = "prim.ctx";
    my $key_priv = "key.priv";
    my $key_pub = "key.pub";
    my $key_name = "key.name";
    my $ket_ctx = "key.ctx";
    assert_script_run "mkdir $test_dir";
    assert_script_run "cd $test_dir";
    assert_script_run "tpm2_createprimary -Q -C o -c $prim_ctx -T tabrmd";
    assert_script_run "tpm2_create -Q -g sha256 -G aes -u $key_pub -r $key_priv -C $prim_ctx -T tabrmd";
    assert_script_run "tpm2_load -C $prim_ctx -u $key_pub -r $key_priv -n $key_name -c $ket_ctx -T tabrmd";
    assert_script_run "tpm2_changeauth -c $ket_ctx -C $prim_ctx -r $key_priv newkeyauth -T tabrmd";
    assert_script_run "tpm2_clear -T tabrmd";

    # Modify authorization for a NV Index Requires Extended Session Support
    my $ses_ctx = "session.ctx";
    assert_script_run "tpm2_startauthsession -S $ses_ctx -T tabrmd";
    assert_script_run "tpm2_policycommandcode -S $ses_ctx -L policy.nvchange TPM2_CC_NV_ChangeAuth -T tabrmd";

    # TPM2_CC_NV_ChangeAuth
    my $nv_val = "0x1500015";
    assert_script_run "tpm2_flushcontext $ses_ctx -T tabrmd";
    assert_script_run "tpm2_nvdefine $nv_val -C o -s 32 -a \"authread|authwrite\" -L policy.nvchange -T tabrmd";
    assert_script_run "tpm2_startauthsession --policy-session -S $ses_ctx -T tabrmd";
    assert_script_run "tpm2_policycommandcode -S $ses_ctx -L policy.nvchange TPM2_CC_NV_ChangeAuth -T tabrmd";
    assert_script_run "tpm2_changeauth -p session:$ses_ctx -c $nv_val newindexauth -T tabrmd";
    assert_script_run "tpm2_clear -T tabrmd";

    # Tpm2_changeauth - Configures authorization values for the various hierarchies, NV indices
    # Set owner, endorsement and lockout authorizations to $new_pass
    my $new_pass = "newpass";
    my $newer_pass = "newerpass";
    assert_script_run "tpm2_changeauth -c owner $new_pass -T tabrmd";
    assert_script_run "tpm2_changeauth -c endorsement $new_pass -T tabrmd";
    assert_script_run "tpm2_changeauth -c lockout $new_pass -T tabrmd";

    # Change owner, endorsement and lockout authorizations
    assert_script_run "tpm2_changeauth -c o -p $new_pass $newer_pass -T tabrmd";
    assert_script_run "tpm2_changeauth -c e -p $new_pass $newer_pass -T tabrmd";
    assert_script_run "tpm2_changeauth -c l -p $new_pass $newer_pass -T tabrmd";
    assert_script_run "cd";
}

sub test_flags {
    return {always_rollback => 1};
}

1;
