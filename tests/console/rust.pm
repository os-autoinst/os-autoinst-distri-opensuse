# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cargo
# Summary: Create and run a project
#    Use cargo to create a project which pulls in dependencies online.
# Maintainer: Cris Dywan <cdywan@suse.com>

use base "consoletest";
use testapi;
use package_utils 'install_package';
use Utils::Architectures 'is_aarch64';

sub run {
    select_console('root-console');
    install_package('cargo gcc', trup_reboot => 1);

    select_console('user-console');
    assert_script_run('cargo new testproject');
    assert_script_run(qq(echo 'uuid = "0.8"' >> testproject/Cargo.toml));
    # it takes longer on aarch64, so extend timeout value for aarch64
    my $timeout = (is_aarch64) ? 600 : 300;
    validate_script_output("cargo run --manifest-path testproject/Cargo.toml",
        sub { m/Hello, world!/ }, timeout => $timeout);
}

1;
