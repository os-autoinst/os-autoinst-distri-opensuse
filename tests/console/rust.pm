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
use Utils::Architectures 'is_aarch64';

sub run {
    select_console('root-console');
    zypper_call('in cargo gcc');

    select_console('user-console');
    assert_script_run('cargo new testproject');
    assert_script_run(qq(echo 'uuid = "0.8"' >> testproject/Cargo.toml));
    # it takes longer on aarch64, so extend timeout value for aarch64
    my $timeout = (is_aarch64) ? 600 : 300;
    validate_script_output("cargo run --manifest-path testproject/Cargo.toml",
        sub { m/Hello, world!/ }, timeout => $timeout);
}

sub post_run_hook {
    # Remove testproject directory
    select_console('user-console');
    assert_script_run('rm -rf testproject');

    # Uninstall Cargo
    select_console('root-console');
    zypper_call('rm --clean-deps cargo');
}

sub post_fail_hook {
    select_console 'log-console';
    assert_script_run 'save_y2logs /tmp/rust_y2logs.tar.bz2';
    upload_logs '/tmp/rust_y2logs.tar.bz2';
}
1;
