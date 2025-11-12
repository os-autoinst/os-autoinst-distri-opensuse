# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: python3-docker
# Summary: Test docker-py
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest', -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils;
use utils;
use Utils::Architectures qw(is_x86_64);
use containers::bats;

my $api_version;
my $version;

sub setup {
    my $self = shift;

    my @pkgs = qq(docker jq make python3 python3-docker python3-paramiko python3-pytest python3-pytest-timeout);
    $self->setup_pkgs(@pkgs);

    configure_docker(selinux => 1, tls => 1);

    # Setup docker credentials helpers
    my $credstore_version = "v0.9.3";
    my $arch = go_arch(get_var("ARCH"));
    my $url = "https://github.com/docker/docker-credential-helpers/releases/download/$credstore_version/docker-credential-pass-$credstore_version.linux-$arch";
    run_command "curl -sSLo /usr/local/bin/docker-credential-pass $url";
    run_command "chmod +x /usr/local/bin/docker-credential-pass";

    $version = script_output "python3 -c 'import docker; print(docker.__version__)'";
    record_info("docker-py version", $version);

    patch_sources "docker-py", $version, "tests";

    $api_version = get_var("DOCKER_API_VERSION", script_output 'make --eval=\'version: ; @echo $(TEST_API_VERSION)\' version');
    record_info("API version", $api_version);
    run_command "curl -sSLo /usr/local/bin/pass https://raw.githubusercontent.com/zx2c4/password-store/refs/heads/master/src/password-store.sh";
    run_command "chmod +x /usr/local/bin/pass";
    # Fill credentials store. Taken from https://github.com/docker/docker-py/blob/main/tests/Dockerfile
    run_command "gpg2 --import ./tests/gpg-keys/secret";
    run_command "gpg2 --import-ownertrust ./tests/gpg-keys/ownertrust";
    run_command "yes | pass init \$(gpg2 --no-auto-check-trustdb --list-secret-key | awk '/^sec/{getline; \$1=\$1; print}')";
    run_command "gpg2 --check-trustdb";
}

sub test ($target) {
    # Used by pytest to ignore whole files
    my @ignore = ();
    # Docker Swarm doesn't work with our weird IPv6 setup with multiple "valid" addresses
    push @ignore, (
        "tests/integration/api_swarm_test.py",
        "tests/integration/models_swarm_test.py"
    );
    # This test uses the vieux/sshfs plugin which doesn't seem to be available for other arches
    push @ignore, "tests/integration/api_plugin_test.py" unless is_x86_64;
    my $ignore = join " ", map { "--ignore=$_" } @ignore;

    # Used by pytest to ignore individual tests
    # Format: "FILE::CLASS::FUNCTION"
    my @deselect = ();
    my $deselect = join " ", map { "--deselect=$_" } @deselect;

    my %env = (
        DOCKER_TEST_API_VERSION => $api_version,
        REQUESTS_CA_BUNDLE => "/etc/ssl/ca-bundle.pem",
        # Fix docker-py test issues with datetimes on different timezones by using UTC
        TZ => "UTC",
    );
    my $env = join " ", map { "$_=$env{$_}" } sort keys %env;
    my $pytest_args = "-vv --capture=tee-sys -o junit_logging=all --junit-xml $target.xml $ignore $deselect";

    # For these tests we use the concept of expected failures instead of deselecting them which prevents them from running
    my @xfails = ();
    push @xfails, (
        # Flaky test
        "tests.integration.api_container_test.AttachContainerTest::test_attach_no_stream",
        # This test with websockets is broken
        "tests.integration.api_container_test.AttachContainerTest::test_run_container_reading_socket_ws",
    );
    push @xfails, (
        "tests.unit.api_build_test.BuildTest::test_set_auth_headers_with_dict_and_no_auth_configs",
    ) if (is_sle(">=16"));

    run_command "$env pytest $pytest_args tests/$target &> $target.txt || true", timeout => 3600;

    patch_junit "docker-py", $version, "$target.xml", @xfails;
    parse_extra_log(XUnit => "$target.xml");
    upload_logs("$target.txt");
}

sub run {
    my $self = shift;

    select_serial_terminal;
    $self->setup;

    select_serial_terminal;
    my $default_targets = "unit integration ssh";
    my @targets = split(/\s+/, get_var('RUN_TESTS', $default_targets));
    foreach my $target (@targets) {
        run_command "export DOCKER_HOST=ssh://root@127.0.0.1" if ($target eq "ssh");
        test $target;
    }
}

sub cleanup {
    cleanup_docker;
    script_run "rm -f /usr/local/bin/{docker-credential-pass,pass}";
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup;
    bats_post_hook;
}

sub post_run_hook {
    my ($self) = @_;
    cleanup;
    bats_post_hook;
}

1;
