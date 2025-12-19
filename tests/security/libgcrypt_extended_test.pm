# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Verifies that libgcrypt correctly reports and operates
#          in FIPS kernel mode and non-FIPS mode
# Maintainer: QE Security <none@suse.de>

use base 'opensusebasetest';
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    ensure_serialdev_permissions;

    zypper_call('in gcc libgcrypt-devel crypto-policies-scripts', timeout => 1000);

    my $src = 'libgcrypt-fips-check.c';
    my $bin = 'libgcrypt-fips-test';

    assert_script_run("curl -o $src " . data_url("security/$src"), 90);
    assert_script_run("gcc -std=c11 $src -lgcrypt -lgpg-error -o $bin");

    my $sys_fips_out = script_output('fips-mode-setup --check', proceed_on_failure => 1);

    if (check_var('FIPS_ENV_MODE', '1')) {
        # FIPS crypto policy only (no kernel FIPS)
        if ($sys_fips_out =~ /FIPS mode is enabled\./m) {
            die "Kernel FIPS unexpectedly enabled while running in FIPS_ENV_MODE";
        }
        unless ($sys_fips_out =~ /The current crypto policy \(FIPS\) is based on the FIPS policy\./m) {
            die "ENV FIPS should be enabled, but it is not";
        }
        record_info('FIPS', 'Running in FIPS ENV (crypto-policy) mode');
    } else {
        # Kernel FIPS mode
        unless ($sys_fips_out =~ /FIPS mode is enabled\./m) {
            die "Kernel FIPS expected but not enabled:\n$sys_fips_out";
        }
        record_info('FIPS', 'Running in FIPS kernel mode');
    }

    my $out = script_output("./$bin");
    die "System is in FIPS mode, but libgcrypt reports FIPS disabled" unless $out =~ /^# FIPS Mode:\s*Enabled$/m;
    die "libgcrypt runtime self-test failed:\n$out" if $out =~ /^not ok\b/m;

    record_info('libgcrypt', 'FIPS state and runtime validation successful');
}

1;
