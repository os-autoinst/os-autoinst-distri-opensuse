# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rustup
# Summary: Check if rustup can be installed and works correctly.
# - Test installation through zypper
# - Check if rustup can install a new rust toolchain (nightly)
# - Check if rustup can switch default toolchain
# - TODO
#
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use strict;
use warning;
use testapi;
use utils qw(zypper_call);
use Utils::architectures 'is_aarch64';

sub run {
    # Install rustup from the zypper package.
    select_console('root-console');
    zypper_call('in rustup');

    select_console('user-console');
    my $timeout = (is_aarch64) ? 600 : 300;

    # Check if the rustup and rustc versions are correct as of (2024-04-08).
    test_versions;
    test_installed_toolchain;
    test_switch_to_nightly;
}

# Might be redundant as they just have been installed, therefore, depending on where rustup checks for updates (distro or upstream)
# it would always report the installed version as "up to date" even if it is not.
sub test_versions {
    select_console('user-console');
    validate_script_output("rustup check", qr/Up to date/, fail_message => 'Cannot validate installed rust version or version out of date!');
}

sub test_installed_toolchain {
    select_console('user-console');
    validate_script_output("rustup show", qr/stable-x86_64-unknown-linux-gnu (default)/, fail_message => "Cannot verify toolchain to be 'stable-x86_64-unknown-linux-gnu'.");
}

sub test_switch_to_nightly {
    select_console('user-console');
    assert_script_run('rustup toolchain install nightly');
    assert_script_run('rustup default nightly');
    validate_script_output("rustup show", qr/nightly-x86_64-unknown-linux-gnu (default)/, fail_message => "Cannot switch to nightly rust build.");
}

sub post_run_hook {
    select_console('root-console');
    zypper_call('rm --clean-deps rustup');
}

1;
