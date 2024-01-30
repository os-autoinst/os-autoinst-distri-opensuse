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

    # Create a secret1 from file and inspect it
    record_info("secret create file", "Create new secret from a file");
    script_run("printf T0p_S3cr3t1 > secret1.txt");
    assert_script_run("$runtime secret create secret1 secret1.txt", fail_message => "Error creating secret from file", timeout => 60);
    record_info("secret inspect file", script_output("$runtime secret inspect secret1"));

    # Create a secret2 from CLI and inspect it
    record_info("secret create CLI", "Create a new secret directly from CLI");
    assert_script_run("printf T0p_S3cr3t2 | $runtime secret create secret2 -", fail_message => "Error creating secret from CLI", timeout => 60);
    record_info("secret inspect CLI", script_output("$runtime secret inspect secret2"));

    # Check if secret exists (only in podman)
    if ($runtime =~ 'podman') {
        record_info("secret exists", "In Podman, check that each created secret exists");
        assert_script_run("podman secret exists secret1", fail_message => "Error checking if secret exists");
        assert_script_run("podman secret exists secret2", fail_message => "Error checking if secret exists");
        # This secret3 does not exist and thus `secret exists` must return 1
        assert_script_run("! podman secret exists secret3", fail_message => "Error checking if secret exists");
    }

    # List all secrets
    record_info("secret ls", script_output("$runtime secret ls"));
    assert_script_run("$runtime secret ls");

    # Run two containers passing secret1 as an env variable and secret2 as default
    my $runtime_command = ($runtime =~ 'docker') ? 'service create' : 'run';
    record_info("Access secrets");
    script_retry("$runtime pull registry.opensuse.org/opensuse/bci/bci-busybox:latest",
        retry => 3, delay => 10, timeout => 120);

    # secret1 testing (default secret)
    validate_script_output("$runtime $runtime_command --name secret1-test --secret secret1 bci-busybox:latest cat /run/secrets/secret1", sub { m/T0p_S3cr3t1/ });
    # Commit the container and check that the secrets are not in it
    record_info("Commit cont", "Commit container secret1-test");
    assert_script_run("$runtime commit secret1-test secret1-test-image");
    my $output = script_output("$runtime $runtime_command --name secret1-test-commit secret1-test-image:latest cat /run/secrets/secret1", proceed_on_failure => 1);
    die("Secret commited") if ($output !~ m/T0p_S3cr3t1/);

    # Accessing secrets as env variables is not available in Docker
    if ($runtime =~ 'podman') {
        # secret2 testing (env secret)
        validate_script_output("podman run --name secret2-test --secret secret2,type=env,target=TOP_SECRET2 bci-busybox:latest printenv TOP_SECRET2", sub { m/T0p_S3cr3t2/ });
        # Commit the container and check that the secrets are not in it
        record_info("Commit cont", "Commit container secret2-test");
        assert_script_run("podman commit secret2-test secret2-test-image");
        $output = script_output("podman run --name secret2-test-commit secret2-test-image:latest printenv TOP_SECRET2", proceed_on_failure => 1);
        die("Secret commited") if ($output !~ m/T0p_S3cr3t2/);
    }

    # Remove secrets
    record_info("secret rm", "Remove all secrets created");
    assert_script_run("$runtime secret rm secret1 secret2");
    validate_script_output("$runtime secret ls --quiet", sub { m// }, fail_message => "Secrets have not been deleted");

    # Stop the swarm in Docker
    assert_script_run("docker swarm leave --force") if ($runtime =~ 'docker');
}

1;
