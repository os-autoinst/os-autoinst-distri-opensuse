# SUSE's openQA tests
#
# Copyright 2015-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: a2ps
# Summary: a2ps test based on: https://progress.opensuse.org/issues/9472
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call "in a2ps";
    assert_script_run("curl https://www.suse.com > /tmp/suse.html");
    validate_script_output "a2ps -o /tmp/suse.ps /tmp/suse.html 2>&1", sub { m/saved into the file/ }, 3;
}

1;

