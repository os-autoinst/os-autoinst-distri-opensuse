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
#          this test module will cover self contained tool.
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#64905, tc#1742297

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Display PCR values
    validate_script_output "systemctl status tpm2-abrmd.service", sub { m/Active:\sactive/ };
    # List the supported PCR
    validate_script_output "tpm2_pcrread -T tabrmd", sub {
        m/
             sha1.*
             sha256.*
             sha384.*
             sha512.*/sx
    };

    # Retrieves random bytes from the TPM
    my $test_dir  = "tpm2_tools";
    my $test_file = "random.out";
    assert_script_run "mkdir $test_dir";
    assert_script_run "cd $test_dir";
    assert_script_run "tpm2_getrandom -o $test_file 64 -T tabrmd";
    validate_script_output "ls -l $test_file|awk '{print $5}'", sub { m/64/ };

    # Hash a file with sha1 hash algorithm and save the hash and ticket to a file
    my $test_data = "data.txt";
    my $hash_file = "ticket.bin";
    assert_script_run "echo test > $test_data";
    assert_script_run "tpm2_hash -C e -g sha1 -t $hash_file $test_data -T tabrmd";

    # Define a TPM Non-Volatile (NV) index
    my $nv_val = "0x1500016";
    validate_script_output "tpm2_nvdefine $nv_val -C 0x40000001 -s 32 -a 0x2000A -T tabrmd", sub { m/nv-index:\s$nv_val/ };

    # Display all defined Non-Volatile (NV)s indices
    validate_script_output "tpm2_nvreadpublic -T tabrmd", sub {
        m/
             value:\s0xA000200.*
             size:\s32.*/sx
    };

    # Undefine the nv index
    assert_script_run "tpm2_nvundefine $nv_val -T tabrmd";

    # Clears lockout, endorsement and owner hierarchy authorization values
    assert_script_run "tpm2_clear -T tabrmd";
    validate_script_output "tpm2_nvreadpublic -T tabrmd|wc -l", sub { m/0/ };
    assert_script_run "cd";
}

sub test_flags {
    return {always_rollback => 1};
}

1;
