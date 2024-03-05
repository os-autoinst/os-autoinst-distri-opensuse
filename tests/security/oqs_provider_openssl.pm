# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: run upstream testsuite of OQS Provider
#
# Maintainer: QE Security <none@suse.de>

use strict;
use warnings;
use base 'opensusebasetest';
use serial_terminal 'select_serial_terminal';
use testapi;
use utils 'zypper_call';
use version_utils qw(is_sle);

sub run {
    select_serial_terminal;

    if (zypper_call("--no-refresh if oqs-provider") != 0) {
        record_info('SKIPPING TEST', "Skipping test due to missing oqs-provider package.");
    } else {
        zypper_call("in gcc wget cmake oqs-provider liboqs-devel libopenssl-3-devel");

        assert_script_run("wget --quiet " . data_url("security/oqs-provider-0.5.0.tar.gz"));
        assert_script_run("tar xf oqs-provider-0.5.0.tar.gz && cd oqs-provider-0.5.0");
        assert_script_run("cmake -S . -B _build && cmake --build _build");
        assert_script_run("cd _build && ctest --parallel 5 --rerun-failed --output-on-failure -V");
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
