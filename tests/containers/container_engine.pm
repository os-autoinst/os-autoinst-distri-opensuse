# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2013-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: docker/podman engine
# Summary: Test docker/podman installation and extended usage
# - docker/podman package can be installed
# - firewall is configured correctly
# - docker daemon can be started (if docker runtime)
# - images can be searched on the Docker Hub
# - images can be pulled from the Docker Hub
# - local images can be listed (with and without tag)
# - containers can be run and created
# - containers state can be saved to an image
# - network is working inside of the containers
# - containers can be stopped
# - containers can be deleted
# - images can be deleted
# - build a docker image
# - attach a volume
# - expose a port
# - test networking outside of host
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::utils;
use containers::container_images;

sub basic_container_tests {
    my %args = @_;
    my $runtime = $args{runtime};
    die "Undefined container runtime" unless $runtime;
    my $image = "registry.opensuse.org/opensuse/tumbleweed";

    ## Test search feature
    validate_script_output("$runtime search --no-trunc --format 'table {{.Name}} {{.Description}}' tumbleweed", sub { m/Official openSUSE Tumbleweed images/ }, timeout => 300);

    # Test pulling and display of images
    script_retry("$runtime image pull $image", timeout => 600, retry => 3, delay => 120);
    validate_script_output("$runtime image ls", qr/tumbleweed/);

    ## Create test container
    assert_script_run("$runtime create --name basic_test_container $image sleep infinity");
    validate_script_output("$runtime container ls --all", qr/basic_test_container/);

    ## Test start/stop/pause
    assert_script_run("$runtime container start basic_test_container");
    validate_script_output("$runtime ps", qr/basic_test_container/);
    validate_script_output("$runtime container inspect --format='{{.State.Running}}' basic_test_container", qr/true/);
    assert_script_run("$runtime pause basic_test_container");
    # docker and podman differ here - in docker paused containers are still in State.Running = true, in podman not
    if ($runtime eq 'docker') {
        validate_script_output("$runtime ps", sub { $_ =~ m/.*(Paused).*basic_test_container.*/ });
        validate_script_output("$runtime container inspect --format='{{.State.Running}}' basic_test_container", qr/true/);
    } else {
        validate_script_output("$runtime ps", sub { $_ !~ m/basic_test_container/ });
        validate_script_output("$runtime container inspect --format='{{.State.Running}}' basic_test_container", qr/false/);
    }
    assert_script_run("$runtime unpause basic_test_container");
    validate_script_output("$runtime ps", qr/basic_test_container/);
    validate_script_output("$runtime container inspect --format='{{.State.Running}}' basic_test_container", qr/true/);
    assert_script_run("$runtime stop basic_test_container");
    if (script_output("$runtime ps") =~ m/basic_test_container/) {
        record_soft_failure("bsc#1212825 race condition in docker/podman stop");
        # We still expect the container to eventually stop
        validate_script_output_retry("$runtime ps", sub { $_ !~ m/basic_test_container/ }, retry => 3, delay => 60);
    }
    validate_script_output("$runtime container inspect --format='{{.State.Running}}' basic_test_container", qr/false/);
    assert_script_run("$runtime container start basic_test_container");
    validate_script_output("$runtime ps", qr/basic_test_container/);
    validate_script_output("$runtime container inspect --format='{{.State.Running}}' basic_test_container", qr/true/);
    assert_script_run("$runtime container restart basic_test_container");
    validate_script_output("$runtime ps", qr/basic_test_container/);
    validate_script_output("$runtime container inspect --format='{{.State.Running}}' basic_test_container", qr/true/);

    ## Test logs
    assert_script_run("$runtime run -d --name logs_test $image echo 'log test canary string'");
    # retry because it could be that the log is not yet collected after the previous command completes
    validate_script_output_retry("$runtime logs logs_test", qr/log test canary string/, retry => 3, delay => 60);
    assert_script_run("$runtime container stop logs_test");
    assert_script_run("$runtime container rm logs_test");

    ## Test exec and image creation
    assert_script_run("$runtime container exec basic_test_container touch /canary");
    assert_script_run("$runtime container commit basic_test_container example.com/tw-commit_test");
    validate_script_output("$runtime image ls --all", qr?example.com/tw-commit_test?);
    assert_script_run("$runtime run --rm example.com/tw-commit_test stat /canary", fail_message => "canary file not present in generated container");
    assert_script_run("$runtime image rm example.com/tw-commit_test");

    ## Test connectivity inside the container
    assert_script_run("$runtime container exec basic_test_container curl -sfI https://opensuse.org", fail_message => "cannot reach opensuse.org");

    ## Test `--init` option, i.e. the container process won't be PID 1 (to avoid zombie processes)
    # Ensure PID 1 has either the $runtime-init (e.g. podman-init) OR /init (e.g. `/dev/init) suffix
    validate_script_output("$runtime run --rm --init $image ps --no-headers -xo 'pid args'", sub { $_ =~ m/\s*1 .*(${runtime}-|\/)init .*/ });
    # Ensure the `ps` command is not running as PID 1. either
    validate_script_output("$runtime run --rm --init $image ps --no-headers -xo 'pid args'", sub { $_ =~ m/[02-9][0-9]* .*ps.*/ });

    ## Test prune
    assert_script_run("$runtime container commit basic_test_container example.com/prune-test");
    validate_script_output("$runtime image ls --all", qr?example.com/prune-test?);
    assert_script_run("$runtime image prune -af");
    validate_script_output("$runtime ps", sub { $_ !~ m?example.com/prune-test? });
    validate_script_output("$runtime image ls", qr/tumbleweed/, fail_message => "Tumbleweed image removed, despite being in use");
    assert_script_run("$runtime system prune -f");
    validate_script_output("$runtime image ls", qr/tumbleweed/, fail_message => "Tumbleweed image removed, despite being in use");
    assert_script_run("! $runtime rmi -a");    # should not be possible because image is in use

    ## Removing containers
    assert_script_run("$runtime container stop basic_test_container");
    assert_script_run("$runtime container rm basic_test_container");
    validate_script_output("$runtime container ls --all", sub { $_ !~ m/basic_test_container/ });

    ## Note: Leave the tumbleweed container to save some bandwidth. It is used in other test modules as well.
}

sub run {
    my ($self, $args) = @_;
    die('You must define a engine') unless ($args->{runtime});
    $self->{runtime} = $args->{runtime};
    select_serial_terminal;

    my $dir = "/root/DockerTest";

    if (get_var('CONTAINERS_CGROUP_VERSION')) {
        switch_cgroup_version($self, get_var('CONTAINERS_CGROUP_VERSION'));
    }

    my $engine = $self->containers_factory($self->{runtime});

    # Test the connectivity of Docker containers
    check_containers_connectivity($engine);

    basic_container_tests(runtime => $self->{runtime});
    # Build an image from Dockerfile and run it
    build_and_run_image(runtime => $engine, dockerfile => 'Dockerfile.python3', base => registry_url('python', '3'));

    # Once more test the basic functionality
    runtime_smoke_tests(runtime => $engine);

    # Smoke test for engine search
    test_search_registry($engine);

    # Clean the container host
    $engine->cleanup_system_host();
}

sub post_fail_hook {
    my ($self) = @_;
    if ($self->{runtime} eq 'podman') {
        select_console 'log-console';
        script_run "podman version | tee /dev/$serialdev";
        script_run "podman info --debug | tee /dev/$serialdev";
    }
    $self->SUPER::post_fail_hook;
}

1;

