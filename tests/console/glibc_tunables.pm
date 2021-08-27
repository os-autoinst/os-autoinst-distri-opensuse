# SUSE's openQA tests
#
# Copyright © 2021 Guillaume GARDET
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: glibc
# Summary: Check GLIBC_TUNABLES support
# Maintainer: Guillaume GARDET <guillaume@opensuse.org>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use Utils::Architectures 'is_aarch64';

sub run {
    select_console 'root-console';

    if (is_aarch64 && check_var('AARCH64_MTE_SUPPORTED', '1')) {
        record_info('Testing MTE on aarch64');
        zypper_call 'in gcc';

        select_console 'user-console';
        assert_script_run('curl ' . data_url("console/mte_test.c") . ' -o mte_test.c');

        assert_script_run 'gcc -Wall mte_test.c -o mte_test';

        record_info('Default', 'MTE should be disabled by default');
        assert_script_run('./mte_test');

        record_info('Async', 'MTE Async mode');
        assert_script_run('export GLIBC_TUNABLES="glibc.mem.tagging=1"');
        if (script_run('./mte_test') == 0) {
            die("This run should SegFault, but it passed!");
        }

        record_info('Sync', 'MTE Sync mode');
        assert_script_run('export GLIBC_TUNABLES="glibc.mem.tagging=3"');
        if (script_run('./mte_test') == 0) {
            die("This run should SegFault, but it passed!");
        }

        record_info('Disabled', 'MTE disabled');
        assert_script_run('export GLIBC_TUNABLES="glibc.mem.tagging=0"');
        assert_script_run('./mte_test');

        assert_script_run('export GLIBC_TUNABLES=""');
    }
    else {
        record_info('No GLIBC_TUNABLES', 'No GLIBC_TUNABLES available for testing on this worker');
    }
}

1;
