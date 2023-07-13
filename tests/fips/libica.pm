# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Smoke test for libica on s390x with enabled FIPS mode
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use version_utils qw(is_sle is_transactional);
use transactional qw(trup_call process_reboot);
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';

sub run {
    select_serial_terminal;

    if (script_run('rpm -q libica4 libica-tools') != 0) {
        if (is_transactional) {
            trup_call('pkg install libica');
            process_reboot(trigger => 1);
        } else {
            zypper_call('in libica');
        }
    }

    record_info('libica', script_output('rpm -qi libica4 libica-tools'));
    validate_script_output('icainfo -f', qr/DRBG-SHA-512/);
    validate_script_output('icainfo -v', qr/build:\s+FIPS-SUSE/);

    # check whether libica is not in error state
    # if so all the algorithms are in block state
    my @fips_alg = split(/\n/, script_output('icainfo'));
    # slice the output, keeping just the table of algorithms
    my @tab = @fips_alg[6 .. scalar(@fips_alg) - 4];
    my $i = 0;
    for ($i = 0; $i < $#tab; $i++) {
        my ($state) = (split(/\|/, $tab[$i]))[2];
        last if ($state =~ /yes/i);
    }

    if ($i == $#tab) {
        die("All algorithms are marked as blocked, libica is in an error state.");
    }

    validate_script_output('icainfo -r', qr/Built-in\s+FIPS\s+support:\s+FIPS\s+140-[3-9].*active/);
    validate_script_output('icainfo -c', qr/Built-in\s+FIPS\s+support:\s+FIPS\s+140-[3-9].*active/);
    assert_script_run('icastats -k');
    assert_script_run('icastats -S');
}

1;
