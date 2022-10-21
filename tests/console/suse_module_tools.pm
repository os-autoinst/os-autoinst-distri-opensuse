# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: mokutil pesign-obs-integration
# Summary: Testing functionality of modhash and modsign-verify commands.
# A random module from available loadable modules on the system is picked
# for testing purposes.
# * modhash: the output is checked for correct format
# * modsign-verify: the output is checked for correct format
# Maintainer: Vasileios Anastasiadis <vasilios.anastasiadis@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use version_utils qw(is_sle is_tumbleweed);

sub run {
    select_serial_terminal;

    # Find a random module available on the system
    # Get a list of all modules
    my $mds = script_output("find /lib/modules/\$(uname -r) -type f -name '*.ko'");
    # Get the first module on the list
    my $pth = (split '\n', $mds)[0];

    # Test modhash command
    if (is_sle && !is_sle('=12-sp1') && !is_sle('=12-sp5') && is_sle('<15-sp1')) {
        # Get the output and test it against correct output
        assert_script_run("modhash $pth | grep -E \"$pth: [0-9a-fA-F]+\"");
    }
    # testing modsign-verify command
    if (is_sle('<15-sp1')) {
        # Run command and grep correct output
        assert_script_run("modsign-verify $pth 2>&1 | grep 'good signature\\|bad signature\\|certificate not found\\|module not signed\\|other error\\|Invalid signature format'");
    }
}

1;
