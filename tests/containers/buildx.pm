# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: buildx
# Summary: test buildx plugin
# - install buildx
# - build test image
# - run container with test image
# - cleanup
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils;
use version_utils qw(is_transactional get_os_release);
use transactional qw(trup_call check_reboot_changes);
use containers::common qw(install_docker_when_needed);

my $test_image = "test_buildx";
my $test_container = "test_buildx";

sub run {
    select_serial_terminal;

    my ($running_version, $sp, $host_distri) = get_os_release;
    install_docker_when_needed($host_distri);

    my $pkgs = 'docker-buildx';
    if (is_transactional) {
        trup_call("pkg install $pkgs");
        check_reboot_changes;
    } else {
        zypper_call("in $pkgs");
    }

    my $docker_info = script_output("docker info");
    record_info('Docker info post-install', $docker_info);
    die "docker-buildx not in plugins list" if ($docker_info !~ /plugins\/docker-buildx/);

    assert_script_run('echo -e "FROM busybox\nEXPOSE 5000" > Dockerfile');
    # NOTE: At some point "buildx" will be dropped
    assert_script_run("docker buildx build -t $test_image .");
    assert_script_run("docker run -d -p 54321:5000 --name $test_container $test_image");
    # docker build should use buildx
    validate_script_output("docker build --help", sub { m/buildx/ });
    assert_script_run("docker build -t $test_image .");
}

sub cleanup() {
    script_run("docker rm -vf $test_container");
    script_run("docker rmi $test_image");
    script_run("docker image prune -f");
    script_run("rm -f Dockerfile");
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
