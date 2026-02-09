# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Per TPM2 stack, we would like to add the tpm2-tools tests,
#          from sles15sp2, update tpm2.0-tools to the stable 4 release
#          this test module will cover self contained tool.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64905, poo#105732, tc#1742297, poo#195086

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'systemctl';

sub run {
    select_serial_terminal;

    my $use_tabrmd = get_var('QEMUTPM', 0) != 1 || get_var('QEMUTPM_VER', '') ne '2.0';
    my $tpm_suffix = $use_tabrmd ? '-T tabrmd' : '';

    my $test_dir = 'tpm2_tools';
    my $rand_file = "$test_dir/random.out";
    my $data_file = "$test_dir/data.txt";
    my $hash_file = "$test_dir/ticket.bin";
    my $nv_index = '0x1500016';

    assert_script_run "mkdir -p $test_dir";

    systemctl 'is-active tpm2-abrmd.service';

    # List supported PCR banks
    validate_script_output "tpm2_pcrread $tpm_suffix", sub {
        m/
            sha1.*
            sha256.*
            sha384.*
            sha512.*
        /sx
    };

    # Get random bytes from TPM
    assert_script_run "tpm2_getrandom -o $rand_file 64 $tpm_suffix";
    validate_script_output "stat -c \%s $rand_file", sub { m/^64$/ };

    # Hash a file with sha1 hash algorithm and save the hash and ticket to a file
    assert_script_run "echo test > $data_file";
    assert_script_run "tpm2_hash -C e -g sha1 -t $hash_file $data_file $tpm_suffix";

    # Define a TPM Non-Volatile (NV) index
    validate_script_output "tpm2_nvdefine $nv_index -C 0x40000001 -s 32 -a 0x2000A $tpm_suffix", sub { m/nv-index:\s$nv_index/ };

    # Verify NV index attributes
    # From tpm_tools 5.3+ attribute is output with fixed endianness, so it's displayed in the same way as set in the command
    # We match both to support old versions
    validate_script_output "tpm2_nvreadpublic $tpm_suffix", sub {
        m/
            value:\s0x(A000200|2000A).*
            size:\s32.*
        /sx
    };

    # Clean up NV index
    assert_script_run "tpm2_nvundefine $nv_index $tpm_suffix";

    # Clear TPM and ensure no NV indices remain
    assert_script_run "tpm2_clear $tpm_suffix";
    validate_script_output "tpm2_nvreadpublic $tpm_suffix | wc -l", sub { m/0/ };
}

1;
