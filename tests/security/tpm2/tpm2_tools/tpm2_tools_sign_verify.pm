# Copyright (C) 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Per TPM2 stack, we would like to add the tpm2-tools tests,
#          from sles15sp2, update tpm2.0-tools to the stable 4 release
#          this test module will cover sign and verify function.
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#64905, tc#1742297

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Sign and verify with the TPM using the endorsement hierarchy
    my $test_dir = "tpm2_tools_sign_verify";
    my $prim_ctx = "primary.ctx";
    my $rsa_priv = "rsa.priv";
    my $rsa_pub  = "rsa.pub";
    my $msg_dat  = "message.dat";
    my $rsa_ctx  = "rsa.ctx";
    my $sig_rsa  = "sig.rsa";
    assert_script_run "mkdir $test_dir";
    assert_script_run "cd $test_dir";
    assert_script_run "tpm2_createprimary -C e -c $prim_ctx -T tabrmd";
    assert_script_run "tpm2_create -G rsa -u $rsa_pub -r $rsa_priv -C $prim_ctx -T tabrmd";
    assert_script_run "tpm2_load -C $prim_ctx -u $rsa_pub -r $rsa_priv -c $rsa_ctx -T tabrmd";
    assert_script_run "echo \"my message\" > $msg_dat";
    assert_script_run "tpm2_sign -c $rsa_ctx -g sha256 -o $sig_rsa $msg_dat -T tabrmd";
    assert_script_run "tpm2_verifysignature -c $rsa_ctx -g sha256 -s $sig_rsa -m $msg_dat -T tabrmd";
    assert_script_run "cd";
}

sub test_flags {
    return {always_rollback => 1};
}

1;
