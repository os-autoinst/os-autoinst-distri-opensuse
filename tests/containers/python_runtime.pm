# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: python3-docker & python3-podman
# Summary: Test podman & docker python packages
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils;
use utils;
use containers::common qw(install_packages);
use Utils::Architectures qw(is_x86_64);

my $runtime;

# Translate RPM arch to Go arch
sub deb_arch {
    my $arch = shift;
    if ($arch eq "x86_64") {
        return "amd64";
    } elsif ($arch eq "aarch64") {
        return "arm64";
    } else {
        return $arch;
    }
}

sub setup {
    my $python3 = "python3";
    my @pkgs = ($runtime, "$python3-$runtime");
    push @pkgs, qq(git-core jq make $python3-pytest);
    if ($runtime eq "podman") {
        push @pkgs, qq($python3-fixtures $python3-requests-mock);
    } else {
        push @pkgs, qq(password-store $python3-paramiko $python3-pytest-timeout);
    }
    install_packages(@pkgs);

    # Add IP to /etc/hosts
    my $iface = script_output "ip -4 --json route list match default | jq -Mr '.[0].dev'";
    my $ip_addr = script_output "ip -4 --json addr show $iface | jq -Mr '.[0].addr_info[0].local'";
    assert_script_run "echo $ip_addr \$(hostname) >> /etc/hosts";

    # Enable SSH
    my $algo = "ed25519";
    systemctl 'enable --now sshd';
    assert_script_run "ssh-keygen -t $algo -N '' -f ~/.ssh/id_$algo";
    assert_script_run "cat ~/.ssh/id_$algo.pub >> ~/.ssh/authorized_keys";
    assert_script_run "ssh-keyscan localhost 127.0.0.1 ::1 | tee -a ~/.ssh/known_hosts";

    if ($runtime eq "podman") {
        systemctl "enable --now podman.socket";
    } else {
        assert_script_run "cp -f /etc/docker/daemon.json /etc/docker/daemon.json.bak";
        assert_script_run qq(echo '"hosts": ["tcp://127.0.0.1:2375", "unix:///var/run/docker.sock"]' > /etc/docker/daemon.json);
        record_info("docker daemon.json", script_output("cat /etc/docker/daemon.json"));
        systemctl "daemon-reload";
        systemctl "enable --now docker";
        record_info("docker info", script_output("docker info"));
        # Setup docker credentials helpers
        my $credstore_version = "v0.9.3";
        my $arch = deb_arch(get_var("ARCH"));
        my $url = "https://github.com/docker/docker-credential-helpers/releases/download/$credstore_version/docker-credential-pass-$credstore_version.linux-$arch";
        assert_script_run "curl -sSLo /usr/local/bin/docker-credential-pass $url";
        assert_script_run "chmod +x /usr/local/bin/docker-credential-pass";
    }

    my $version = script_output "$python3 -c 'import $runtime; print($runtime.__version__)'";
    record_info("Version", $version);
    my $branch = ($runtime eq "podman") ? "v$version" : $version;
    my $github_org = ($runtime eq "podman") ? "containers" : "docker";

    # Support these cases for GIT_REPO: [<GITHUB_ORG>]#BRANCH
    # 1. As GITHUB_ORG#TAG: github_user#test-patch
    # 2. As TAG only: main, v1.2.3, etc
    # 3. Empty. Use defaults specified above for $github_org & $branch
    my $repo = get_var("GIT_REPO", "");
    if ($repo =~ /#/) {
        ($github_org, $branch) = split("#", $repo, 2);
    } elsif ($repo) {
        $branch = $repo;
    }

    assert_script_run "cd ~";
    assert_script_run "git clone --branch $branch https://github.com/$github_org/$runtime-py", timeout => 300;
    assert_script_run "cd ~/$runtime-py";

    unless ($repo) {
        my @patches = ($runtime eq "podman") ? qw(572 575) : qw(3261 3290 3354);
        foreach my $patch (@patches) {
            assert_script_run "curl -O " . data_url("containers/patches/$runtime-py/$patch.patch");
            # We need git 2.47.0+ to use `--ours` with `git apply -3`
            assert_script_run "git apply -3 --ours $patch.patch";
        }
    }

    if ($runtime eq "docker") {
        # Fill credentials store. Taken from https://github.com/docker/docker-py/blob/main/tests/Dockerfile
        assert_script_run "gpg2 --import ./tests/gpg-keys/secret";
        assert_script_run "gpg2 --import-ownertrust ./tests/gpg-keys/ownertrust";
        assert_script_run "yes | pass init \$(gpg2 --no-auto-check-trustdb --list-secret-key | awk '/^sec/{getline; \$1=\$1; print}')";
        assert_script_run "gpg2 --check-trustdb";
    }
}

sub test {
    my $target = shift;

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
    }
    my $deselect = join " ", map { "--deselect=$_" } @deselect;

    # Tests directory
    my $tests = ($runtime eq "podman") ? "podman/tests" : "tests";

    my %env = ();
    if ($runtime eq "docker") {
        my $api_version = script_output 'make --eval=\'version: ; @echo $(TEST_API_VERSION)\' version';
        $env{DOCKER_TEST_API_VERSION} = $api_version;
        # Fix docker-py test issues with datetimes on different timezones by using UTC
        $env{TZ} = "UTC";
    }
    my $env = join " ", map { "$_=$env{$_}" } sort keys %env;
    my $pytest_args = "-vv --capture=tee-sys -o junit_logging=all --junit-xml $target.xml $ignore $deselect";

    script_run "$env pytest $pytest_args $tests/$target |& tee $target.txt", timeout => 3600;

    # Patch the test name in the first line of the JUnit XML file so each target is parsed independently
    my $name = ($runtime eq "podman") ? "pytest" : "docker-py";
    assert_script_run qq{sed -ri '0,/name=/s/name="$name"/name="pytest-$target"/' $target.xml};
    parse_extra_log(XUnit => "$target.xml");
    upload_logs("$target.txt");
}

sub run {
    my ($self, $args) = @_;
    $runtime = $args->{runtime};

    select_serial_terminal;

    setup;

    my @targets = (qw(unit integration));
    foreach my $target (@targets) {
        test $target;
    }
    if ($runtime eq "docker") {
        assert_script_run "export DOCKER_HOST=ssh://root@127.0.0.1";
        test "ssh";
    }
}

sub cleanup() {
    script_run "unset DOCKER_HOST";
    script_run "cp -f /etc/docker/daemon.json.bak /etc/docker/daemon.json";
    script_run "cd / ; rm -rf /root/$runtime-py";
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup;
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = @_;
    cleanup;
    $self->SUPER::post_run_hook;
}

1;
