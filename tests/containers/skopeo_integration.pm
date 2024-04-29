# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: skopeo
# Summary: Upstream skopeo integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal select_user_serial_terminal);
use utils qw(script_retry ensure_serialdev_permissions);
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product get_addon_fullname);
use containers::common;

my $test_dir = "/var/tmp";
my $skopeo_version = "";

sub run_tests {
    my %params = @_;
    my ($rootless, $skip_tests) = ($params{rootless}, $params{skip_tests});

    my $log_file = "skopeo-" . ($rootless ? "user" : "root") . ".tap";

    assert_script_run "cp -r systemtest.orig systemtest";
    my @skip_tests = split(/\s+/, get_var('SKOPEO_BATS_SKIP', '') . " " . $skip_tests);
    script_run "rm systemtest/$_.bats" foreach (@skip_tests);

    assert_script_run "echo $log_file .. > $log_file";
    script_run "SKOPEO_BINARY=/usr/bin/skopeo bats --tap systemtest | tee -a $log_file", 1200;
    parse_extra_log(TAP => $log_file);
    assert_script_run "rm -rf systemtest";
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    if (is_sle) {
        add_suseconnect_product(get_addon_fullname('phub'));
    }

    # Install tests dependencies
    my @pkgs = qw(apache2-utils bats go jq podman skopeo);
    install_packages(@pkgs);

    # Create user if not present
    if (script_run("grep $testapi::username /etc/passwd") != 0) {
        my $serial_group = script_output "stat -c %G /dev/$testapi::serialdev";
        assert_script_run "useradd -m -G $serial_group $testapi::username";
        assert_script_run "echo '${testapi::username}:$testapi::password' | chpasswd";
        ensure_serialdev_permissions;
        select_console "user-console";
    } else {
        select_user_serial_terminal();
    }

    # Download skopeo sources
    my $test_dir = "/var/tmp";
    $skopeo_version = script_output "skopeo --version  | awk '{ print \$3 }'";
    assert_script_run "cd $test_dir";
    script_retry("curl -sL https://github.com/containers/skopeo/archive/refs/tags/v$skopeo_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "cd skopeo-$skopeo_version/";
    assert_script_run "cp -r systemtest systemtest.orig";

    run_tests(rootless => 1, skip_tests => get_var('SKOPEO_BATS_SKIP_USER', ''));

    select_serial_terminal;
    assert_script_run("cd $test_dir/skopeo-$skopeo_version/");

    run_tests(rootless => 0, skip_tests => get_var('SKOPEO_BATS_SKIP_ROOT', ''));
}

sub cleanup() {
    script_run("rm -rf $test_dir/skopeo-$skopeo_version/");
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup();
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = @_;
    cleanup();
    $self->SUPER::post_run_hook;
}

1;
