# Copyright 2020-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Per TPM2 stack, we would like to add the tpm2-tools tests,
#          from sles15sp2, update tpm2.0-tools to the stable 4 release
#          this test module will cover self contained tool.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64905, poo#105732, tc#1742297

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    my $tpm_suffix = '';
    $tpm_suffix = '-T tabrmd' if (get_var('QEMUTPM', 0) != 1 || get_var('QEMUTPM_VER', '') ne '2.0');

    # Display PCR values
    validate_script_output "systemctl status tpm2-abrmd.service", sub { m/Active:\sactive/ };
    # List the supported PCR
    validate_script_output "tpm2_pcrread $tpm_suffix", sub {
        m/
             sha1.*
             sha256.*
             sha384.*
             sha512.*/sx
    };

    # Retrieves random bytes from the TPM
    my $test_dir = "tpm2_tools";
    my $test_file = "random.out";
    assert_script_run "mkdir $test_dir";
    assert_script_run "cd $test_dir";
    assert_script_run "tpm2_getrandom -o $test_file 64 $tpm_suffix";
    validate_script_output "ls -l $test_file|awk '{print $5}'", sub { m/64/ };

    # Hash a file with sha1 hash algorithm and save the hash and ticket to a file
    my $test_data = "data.txt";
    my $hash_file = "ticket.bin";
    assert_script_run "echo test > $test_data";
    assert_script_run "tpm2_hash -C e -g sha1 -t $hash_file $test_data $tpm_suffix";

    # Define a TPM Non-Volatile (NV) index
    my $nv_val = "0x1500016";
    validate_script_output "tpm2_nvdefine $nv_val -C 0x40000001 -s 32 -a 0x2000A $tpm_suffix", sub { m/nv-index:\s$nv_val/ };

    # Display all defined Non-Volatile (NV)s indices
    # from tpm_tools 5.3+ attribute is output with fixed endianness, so it's displayed in the same way as set in the command
    # we match both to support also old versions
    validate_script_output "tpm2_nvreadpublic $tpm_suffix", sub {
        m/ value:\s0x(A000200|2000A).*
           size:\s32.*/sx
    };

    # Undefine the nv index
    assert_script_run "tpm2_nvundefine $nv_val $tpm_suffix";

    # Clears lockout, endorsement and owner hierarchy authorization values
    assert_script_run "tpm2_clear $tpm_suffix";
    validate_script_output "tpm2_nvreadpublic $tpm_suffix|wc -l", sub { m/0/ };
    assert_script_run "cd";
}

1;
