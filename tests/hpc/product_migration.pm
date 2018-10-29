# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Checking ability to migrate from SLE 12 with HPC module to SLE 12 HPC Product
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
# Tags: https://fate.suse.com/326567

use base "hpcbase";
use strict;
use warnings;
use testapi;
use utils;
use registration 'add_suseconnect_product';

sub run {
    my $self            = shift;
    my $suseconnect_str = ' -e testing@suse.com -r ';
    $self->select_serial_terminal;

    script_run('ls -la /etc/products.d/');
    my $out = script_output('SUSEConnect -s', 30, proceed_on_failure => 1);
    assert_script_run('SUSEConnect --cleanup', 200) if $out =~ /Error: Invalid system credentials/s;
    add_suseconnect_product('SLES', '12.4', get_var('ARCH'), $suseconnect_str . get_required_var('SCC_REGCODE'));
    add_suseconnect_product('sle-module-hpc',           '12');
    add_suseconnect_product('sle-module-web-scripting', '12');
    zypper_call('in switch_sles_sle-hpc');
    assert_script_run('switch_to_sle-hpc' . $suseconnect_str . get_required_var('SCC_REGCODE_HPC_PRODUCT'), 600);
    script_run('ls -la /etc/products.d/');
}

1;
