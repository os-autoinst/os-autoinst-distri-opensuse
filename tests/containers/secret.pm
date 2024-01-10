# SUSE's openQA tests
#
# Copyright 2023-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman, docker
# Summary: Test the `secret` subcommand for Docker and Podman
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::container_images;

sub run {
    my ($self, $args) = @_;
    my $runtime = $args->{runtime};
    my $output = '';

    select_serial_terminal();

    # In Docker, secrets can only be used in a swarm
    if ($runtime =~ 'docker') {
        my $ip_addr = script_output(qq(ip -6 address show dev eth0 |
        awk '/inet6/{split(\$2, a, "/"); print a[1]; exit;}'));
        record_info("docker swarm init", "Initializing docker swarm in IP $ip_addr");
        assert_script_run("docker swarm init --advertise-addr $ip_addr");
    }

    # Create a secret1 from CLI and inspect it
    record_info("secret create CLI");
    assert_script_run("printf T0p_S3cr3t1 | $runtime secret create secret1 -", fail_message => "Error creating secret from CLI", timeout => 60);
    record_info("secret inspect CLI", script_output("$runtime secret inspect secret1"));

    # Create a secret2 from file and inspect it
    record_info("secret create file");
    script_run("printf T0p_S3cr3t2 > secret2.txt");
    assert_script_run("$runtime secret create secret2 secret2.txt", fail_message => "Error creating secret from file", timeout => 60);
    record_info("secret inspect file", script_output("$runtime secret inspect secret2"));

    # Check if secret exists (only in podman)
    if ($runtime =~ 'podman') {
        record_info("secret exists");
        assert_script_run("podman secret exists secret1", fail_message => "Error checking if secret exists");
        assert_script_run("podman secret exists secret2", fail_message => "Error checking if secret exists");
        # This secret3 does not exist and thus `secret exists` must return 1
        assert_script_run("! podman secret exists secret3", fail_message => "Error checking if secret exists");
    }

    # List all secrets
    record_info("secret ls");
    assert_script_run("$runtime secret ls");

    # Run a container passing secret1 as an env variable and secret2 as default
    my $runtime_command = ($runtime =~ 'docker') ? 'service' : 'run';
    record_info("Access secrets");
    script_run("$runtime pull registry.opensuse.org/opensuse/bci/bci-busybox:latest");
    validate_script_output("$runtime $runtime_command --rm --name secret-test --secret secret1,type=env,target=TOP_SECRET1 --secret secret2 bci-busybox:latest printenv TOP_SECRET1", sub { m/T0p_S3cr3t1/ });
    validate_script_output("$runtime $runtime_command --name secret-test --secret secret1,type=env,target=TOP_SECRET1 --secret secret2 bci-busybox:latest cat /run/secrets/secret2", sub { m/T0p_S3cr3t2/ });
    # Commit the container and check that the secrets are not in it
    record_info("Commit container");
    assert_script_run("$runtime commit secret-test secret-test-image");
    validate_script_output("$runtime $runtime_command --rm --name new-secret-test secret-test-image:latest printenv TOP_SECRET1", sub { !m/T0p_S3cr3t1/ });
    validate_script_output("$runtime $runtime_command --name new-secret-test secret-test-image:latest cat /run/secrets/secret2", sub { !m/T0p_S3cr3t2/ });

    # Remove secrets
    record_info("secret rm");
    assert_script_run("$runtime secret rm secret1 secret2");
    assert_script_run("! $runtime secret ls --quiet", fail_message => "Secrets have not been deleted");

    # Stop the swarm in Docker
    assert_script_run("docker swarm leave --force") if ($runtime == 'docker');
}

1;
