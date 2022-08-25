# XEN regression tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rpm
# Summary: Test the host kernel
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base 'consoletest';
use virt_autotest::common;
use warnings;
use strict;
use virt_autotest::kernel;
use testapi;
use utils;
use qam;

sub run {
    my $self = shift;
    select_console('root-console');
    if (my $pkg = get_var("UPDATE_PACKAGE")) {
        validate_script_output("zypper if $pkg", sub { m/(?=.*TEST_\d+)(?=.*up-to-date)/s });
    }
    if (check_var('PATCH_WITH_ZYPPER', '1')) {
        assert_script_run("dmesg --level=emerg,crit,alert,err -tx |sort |comm -23 - /tmp/dmesg_err_before.txt > /tmp/dmesg_err.txt");
    } else {
        assert_script_run("dmesg --level=emerg,crit,alert,err -x > /tmp/dmesg_err.txt");
    }
    if (script_run("[[ -s /tmp/dmesg_err.txt ]]") == 0) {
        upload_logs('/tmp/dmesg_err.txt');
        upload_logs('/tmp/dmesg_err_before.txt') if (script_run("[[ -s /tmp/dmesg_err_before.txt ]]") == 0);
        record_soft_failure "The dmesg_err.txt needs to be checked manually! poo#55555";
        script_run("cat /tmp/dmesg_err.txt");
    }
}

sub post_run_hook {
}

sub test_flags {
    return {fatal => 1};
}

1;

