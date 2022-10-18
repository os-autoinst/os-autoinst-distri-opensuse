# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Checking ability to migrate from SLE 12 with HPC module to SLE 12 HPC Product
# Maintainer: Kernel QE <kernel-qa@suse.de>
# Tags: https://fate.suse.com/326567

use Mojo::Base 'hpcbase', -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use registration 'add_suseconnect_product';

sub run ($self) {
    my $suseconnect_str = ' -e testing@suse.com -r ';
    my $version = get_required_var('VERSION');
    ## replace SP-X with 12.X as this form is expected by SUSEConnect
    $version =~ s/-SP/./;
    select_serial_terminal;

    script_run('ls -la /etc/products.d/');
    my $out = script_output('SUSEConnect -s', 30, proceed_on_failure => 1);
    assert_script_run('SUSEConnect --cleanup', 200) if $out =~ /Error: Invalid system credentials/s;
    add_suseconnect_product('SLES', $version, get_required_var('ARCH'), $suseconnect_str . get_required_var('SCC_REGCODE'));
    add_suseconnect_product('sle-module-hpc', '12');
    add_suseconnect_product('sle-module-web-scripting', '12');
    zypper_call('in switch_sles_sle-hpc');
    assert_script_run('switch_to_sle-hpc' . $suseconnect_str . get_required_var('SCC_REGCODE_HPC_PRODUCT'), 600);
    script_run('ls -la /etc/products.d/');
}

1;
