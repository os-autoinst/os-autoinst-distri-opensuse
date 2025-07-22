# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check if kdump is disabled by default
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use testapi;

sub run {
    assert_script_run("grep ^0 /sys/kernel/kexec_crash_loaded", fail_message => 'kdump should be disabled');
}

1;
