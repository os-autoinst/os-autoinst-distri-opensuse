# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: python3-docker & python3-podman
# Summary: Test podman & docker python packages
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest', -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils;
use utils;
use Utils::Architectures qw(is_x86_64);
use registration qw(add_suseconnect_product get_addon_fullname);
use containers::common qw(install_packages);
use containers::bats;

my $api_version;
my $runtime;

# Translate RPM arch to Go arch
sub deb_arch ($arch) {
    return "amd64" if $arch eq "x86_64";
    return "arm64" if $arch eq "aarch64";
    return $arch;
}

sub setup {
    add_suseconnect_product(get_addon_fullname('python3')) if (is_sle('>=15-SP4') && is_sle("<16"));
    my $python3 = is_sle("<16") ? "python311" : "python3";
    my @pkgs = ($runtime, $python3, "$python3-$runtime");
    push @pkgs, qq(jq make $python3-pytest);
    push @pkgs, $runtime eq 'podman' ? qq($python3-fixtures $python3-requests-mock) : qq($python3-paramiko $python3-pytest-timeout);
    install_packages(@pkgs);
    install_git;

    # Add IP to /etc/hosts
    my $iface = script_output "ip -4 --json route list match default | jq -Mr '.[0].dev'";
    my $ip_addr = script_output "ip -4 --json addr show $iface | jq -Mr '.[0].addr_info[0].local'";
    run_command "echo $ip_addr \$(hostname) >> /etc/hosts";

    # Enable SSH
    my $algo = "ed25519";
    systemctl 'enable --now sshd';
    run_command "ssh-keygen -t $algo -N '' -f ~/.ssh/id_$algo";
    run_command "cat ~/.ssh/id_$algo.pub >> ~/.ssh/authorized_keys";
    run_command "ssh-keyscan localhost 127.0.0.1 ::1 | tee -a ~/.ssh/known_hosts";

    if ($runtime eq "podman") {
        systemctl "enable --now podman.socket";
    } else {
        run_command q(sed -ri 's,^(DOCKER_OPTS)=.*,\1="-H tcp://127.0.0.1:2375 -H unix:///var/run/docker.sock",' /etc/sysconfig/docker);
        record_info("sysconfig", script_output("cat /etc/sysconfig/docker"));
        if (is_sle("<16")) {
            # Workaround for https://bugzilla.suse.com/show_bug.cgi?id=1248755
            run_command "export DOCKER_HOST=tcp://127.0.0.1:2375";
            run_command "echo 0 > /etc/docker/suse-secrets-enable";
        }
        systemctl "enable docker";
        systemctl "restart docker";
        record_info("docker info", script_output("docker info"));
        # Setup docker credentials helpers
        my $credstore_version = "v0.9.3";
        my $arch = deb_arch(get_var("ARCH"));
        my $url = "https://github.com/docker/docker-credential-helpers/releases/download/$credstore_version/docker-credential-pass-$credstore_version.linux-$arch";
        run_command "curl -sSLo /usr/local/bin/docker-credential-pass $url";
        run_command "chmod +x /usr/local/bin/docker-credential-pass";
    }

    # Transform "python311" into "python3.11" and leave "python3" as is
    $python3 =~ s/^python3(\d{2})$/python3.$1/;
    my $version = script_output "$python3 -c 'import $runtime; print($runtime.__version__)'";
    record_info("Version", $version);

    # podman-py uses v$version in tags while docker-py uses bare version
    $version = ($runtime eq "podman") ? "v$version" : $version;
    my $test_dir = ($runtime eq "podman") ? "podman/tests" : "tests";
    patch_sources "$runtime-py", $version, $test_dir;

    if ($runtime eq "docker") {
        $api_version = get_var("DOCKER_API_VERSION", script_output 'make --eval=\'version: ; @echo $(TEST_API_VERSION)\' version');
        record_info("API version", $api_version);
    }

    if ($runtime eq "docker") {
        run_command "curl -sSLo /usr/local/bin/pass https://raw.githubusercontent.com/zx2c4/password-store/refs/heads/master/src/password-store.sh";
        run_command "chmod +x /usr/local/bin/pass";
        # Fill credentials store. Taken from https://github.com/docker/docker-py/blob/main/tests/Dockerfile
        run_command "gpg2 --import ./tests/gpg-keys/secret";
        run_command "gpg2 --import-ownertrust ./tests/gpg-keys/ownertrust";
        run_command "yes | pass init \$(gpg2 --no-auto-check-trustdb --list-secret-key | awk '/^sec/{getline; \$1=\$1; print}')";
        run_command "gpg2 --check-trustdb";
    }
}

sub test ($target) {
    # Used by pytest to ignore whole files
    my @ignore = ();
    if ($runtime eq "docker") {
        # Docker Swarm doesn't work with our weird IPv6 setup with multiple "valid" addresses
        push @ignore, (
            "tests/integration/api_swarm_test.py",
            "tests/integration/models_swarm_test.py"
        );
        # This test uses the vieux/sshfs plugin which doesn't seem to be available for other arches
        push @ignore, "tests/integration/api_plugin_test.py" unless is_x86_64;
    }
    my $ignore = join " ", map { "--ignore=$_" } @ignore;

    # Used by pytest to ignore individual tests
    my @deselect = ();
    if ($runtime eq "docker") {
        push @deselect, (
            # This test with websockets is broken
            "tests/integration/api_container_test.py::AttachContainerTest::test_run_container_reading_socket_ws",
            # These 3 tests fail because our patches force log-opts max-file & max-size:
            "tests/integration/api_container_test.py::CreateContainerTest::test_valid_log_driver_and_log_opt",
            "tests/integration/api_container_test.py::CreateContainerTest::test_valid_no_config_specified",
            "tests/integration/api_container_test.py::CreateContainerTest::test_valid_no_log_driver_specified",
            # Flaky test
            "tests/integration/api_container_test.py::AttachContainerTest::test_attach_no_stream"
        );
        if (is_sle("<16")) {
            push @deselect, (
                # These tests fail due to https://bugzilla.suse.com/show_bug.cgi?id=1248755
                "tests/unit/client_test.py::ClientTest::test_default_pool_size_unix",
                "tests/unit/client_test.py::ClientTest::test_pool_size_unix",
                "tests/unit/client_test.py::FromEnvTest::test_default_pool_size_from_env_unix",
                "tests/unit/client_test.py::FromEnvTest::test_pool_size_from_env_unix",
                "tests/unit/api_test.py::UnixSocketStreamTest::test_early_stream_response"
            );
        }
    } else {
        push @deselect, (
            # This test depends on an image available only for x86_64
            "podman/tests/integration/test_manifests.py::ManifestsIntegrationTest::test_manifest_crud"
        ) unless is_x86_64;
    }
    my $deselect = join " ", map { "--deselect=$_" } @deselect;

    # Tests directory
    my $tests = ($runtime eq "podman") ? "podman/tests" : "tests";

    my %env = ();
    if ($runtime eq "docker") {
        $env{DOCKER_TEST_API_VERSION} = $api_version;
        # Fix docker-py test issues with datetimes on different timezones by using UTC
        $env{TZ} = "UTC";
    }
    my $env = join " ", map { "$_=$env{$_}" } sort keys %env;
    my $pytest_args = "-vv --capture=tee-sys -o junit_logging=all --junit-xml $target.xml $ignore $deselect";

    run_command "$env pytest $pytest_args $tests/$target &> $target.txt || true", timeout => 3600;

    # Patch the test name in the first line of the JUnit XML file so each target is parsed independently
    my $name = ($runtime eq "podman") ? "pytest" : "docker-py";
    assert_script_run qq{sed -ri '0,/name=/s/name="$name"/name="pytest-$target"/' $target.xml};
    parse_extra_log(XUnit => "$target.xml");
    upload_logs("$target.txt");
}

sub run {
    my ($self, $args) = @_;
    $runtime = $args->{runtime} // get_var("CONTAINER_RUNTIMES");

    select_serial_terminal;

    setup;

    test $_ foreach (qw(unit integration));
    # This test fails on SLES 15 due to https://bugzilla.suse.com/show_bug.cgi?id=1248755
    if ($runtime eq "docker" && (is_sle(">=16.0") || is_tumbleweed)) {
        run_command "export DOCKER_HOST=ssh://root@127.0.0.1";
        test "ssh";
    }
}

sub cleanup() {
    script_run "unset DOCKER_HOST";
    script_run q(sed -ri 's/^(DOCKER_OPTS)=.*/\1=""/' /etc/sysconfig/docker);
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
