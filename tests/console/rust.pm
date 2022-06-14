# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cargo
# Summary: Create and run a project
#    Use cargo to create a project which pulls in dependencies online.
# Maintainer: Cris Dywan <cdywan@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils qw(zypper_call);

sub run {
    select_console('root-console');
    zypper_call('in cargo gcc');

    select_console('user-console');
    assert_script_run('cargo new testproject');
    assert_script_run(qq(echo 'uuid = "0.8"' >> testproject/Cargo.toml));
    validate_script_output("cargo run --manifest-path testproject/Cargo.toml",
        sub { m/Hello, world!/ }, timeout => 300);
}

1;
