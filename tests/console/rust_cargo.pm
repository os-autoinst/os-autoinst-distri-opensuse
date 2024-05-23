# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cargo
# Summary: Install cargo and assert full functionality
#   - Create a new project
#   - Add documentation
#   - Add a dependency
#   - Validate that the project can be run
#   - Valdiate that documentation can be built by cargo
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils qw(zypper_call);
use Utils::Architectures 'is_aarch64';

sub run {
    select_console('root-console');
    zypper_call('in cargo');

    # Setup test project
    my $proj_name = "test_project";
    my $timeout = (is_aarch64) ? 600 : 300;
    my $test_arg = 'openQA';
    select_console('user-console');
    assert_script_run('cargo new ' . $proj_name . " && cd " . $proj_name);

    cargo_run_test();
    cargo_add_test();
    add_dep_manually_test();
    cargo_project_test(proj_name => $proj_name, test_arg => $test_arg, timeout => $timeout);
    cargo_doc_test($proj_name);
}

sub cargo_run_test {
    # May take logner on aarch64, so extend timeout value for aarch64.
    my $timeout = (is_aarch64) ? 600 : 300;
    validate_script_output("cargo run",
        sub { m/Hello, world!/ }, timeout => $timeout);
}

sub cargo_add_test {
    select_console('user-console');
    # Add a major dependency to the project.
    assert_script_run('cargo add clap --features derive');
}

sub cargo_project_test {
    my %proj_name = @_;
    select_console('user-console');
    # Copy man_or_boy src file to the src directory of the project.
    assert_script_run("[ -f man_or_boy.rs ] || curl -o" . data_url("console/man_or_boy.rs") . " || true");
    validate_script_output("cargo run -- --name " . $proj_name{test_arg}, qr/Hello, world!/, timeout => $proj_name{timeout}, fail_message => "Cannot verfiy script output.");
}

sub cargo_doc_test {
    my $proj_name = @_;
    assert_script_run('cargo doc');
    assert_script_run('ll target/doc/' . $proj_name . '/ | grep index.html');
}

sub add_dep_manually_test {
    select_console('user-console');
    assert_script_run(qq(echo 'uuid = "1.8.0"' >> ./Cargo.toml));
    validate_script_output("cargo tree", qr/uuid v1.8.0/, fail_message => "Cannot find manually added dependency!")
}

sub post_run_hook {
    # Remove project directory
    select_console('user-console');
    assert_script_run('cd ..');
    assert_script_run('rm -rf test_project');

    # Uninstall cargo
    select_console('root-console');
    zypper_call('rm --clean-deps cargo');    # FIXME: This will uninstall gcc if orphaned? Should not be orphaned.
}

sub post_fail_hook {
    select_console('log-console');
    assert_script_run('save_y2logs /tmp/rust_cargo_test_y2logs.tar.bz2');
    upload_logs('/tmp/rust_cargo_test_y2logs.tar.bz2');
}

1;
