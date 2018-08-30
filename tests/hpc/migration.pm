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
use serial_terminal 'select_virtio_console';

sub run {
    my $self     = shift;
    my $scc_code = get_required_var('SCC_REGCODE_HPC');
    select_virtio_console();

    assert_script_run('ls -la /etc/products.d/');
    zypper_call('in switch_sles_sle-hpc');
    script_run('SUSEConnect -s');
    assert_script_run('SUSEConnect -p sle-module-hpc/12/x86_64');
    assert_script_run('SUSEConnect -p sle-module-web-scripting/12/x86_64');
    assert_script_run("switch_to_sle-hpc -e testing\@suse.com -r $scc_code");
    assert_script_run('ls -la /etc/products.d/');
}

1;
