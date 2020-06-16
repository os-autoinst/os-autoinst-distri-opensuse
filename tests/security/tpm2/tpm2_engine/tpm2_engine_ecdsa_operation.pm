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
# Summary: Per TPM2 stack, we would like to add the tpm2-tss-engine,
#          For tpm2_enginee tests, we need tpm2-abrmd serive active.
#          We have several test modules, this test module will cover
#          ECDSA operations.
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#64902, tc#1742298

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # ECDSA operations
    # There is an known issue bsc#1159508
    # Please use the command below to carry out the tests
    my $test_dir  = "tpm2_engine_ecdsa_sign";
    my $test_file = "data";
    my $my_key    = "mykey";
    my $my_sig    = "mysig";
    assert_script_run "mkdir $test_dir";
    assert_script_run "cd $test_dir";
    assert_script_run "echo tpm2test > $test_file";
    assert_script_run "tpm2tss-genkey -a ecdsa -s 2048 $my_key";
    assert_script_run "openssl ec -engine tpm2tss -inform engine -in $my_key -pubout -outform pem -out $my_key.pub";
    assert_script_run "sha256sum $test_file | cut -d ' ' -f 1 | base64 -d > $test_file.hash";
    assert_script_run "openssl pkeyutl -engine tpm2tss -keyform engine -inkey $my_key -sign -in $test_file.hash -out $my_sig";
    validate_script_output "openssl pkeyutl -engine tpm2tss -keyform engine -inkey $my_key -verify -in $test_file.hash -sigfile $my_sig", sub {
        m
            /Signature\sVerified\sSuccessfully/
    };
    assert_script_run "cd";
}

sub test_flags {
    return {always_rollback => 1};
}

1;
