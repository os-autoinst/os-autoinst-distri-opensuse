# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test gnutls credentials2 API for PSK SHA384 binder support
# Maintainer: QE Security <none@suse.de>

use base 'consoletest';
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';

sub run {
    select_serial_terminal;

    if (is_sle('<15-SP7')) {
        record_info('SKIPPED', 'only executing on SLE 15.7+');
        return;
    }

    zypper_call('in gcc curl libgnutls-devel');

    assert_script_run('mkdir -p /tmp/psk_sha384_test');
    assert_script_run('curl -fsSL -o /tmp/psk_sha384_test/psk_sha384_test.c ' . data_url('security/psk_sha384_test.c'));
    assert_script_run('cd /tmp/psk_sha384_test && gcc -O2 -std=gnu11 -Wall -Wextra -o psk_sha384_test psk_sha384_test.c $(pkg-config --cflags --libs gnutls) -lpthread');

    my $tap_file = '/tmp/psk_sha384_test.tap';
    my $err_file = '/tmp/psk_sha384_debug.log';

    my $rc = script_run("cd /tmp/psk_sha384_test && ./psk_sha384_test > $tap_file 2> $err_file");
    script_run("echo '===== TAP OUTPUT ====='");
    script_run("test -e $tap_file && cat $tap_file || true");
    script_run("test -s $err_file && { echo '===== STDERR ====='; cat $err_file; } || true");

    upload_logs($tap_file);
    upload_logs($err_file, failok => 1);

    die "psk_sha384_test failed with rc=$rc" if $rc != 0;
}

sub test_flags {
    return {fatal => 0, milestone => 1};
}

1;
