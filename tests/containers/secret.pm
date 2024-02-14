# SUSE's openQA tests
#
# Copyright 2023-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Test the `secret` subcommand for Podman
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::container_images;
use containers::utils qw(get_podman_version);
use version_utils;

sub run {
    my ($self, $args) = @_;
    my $output = '';

    my $engine = $self->containers_factory('podman');

    my $podman_version = get_podman_version();
    # Skip this module on podman < 3.1.0
    return if (version->parse($podman_version) < version->parse('3.1.0'));

    select_serial_terminal();

    # Create a secret1 from file and inspect it
    record_info("secret create file", "Create new secret from a file");
    script_run("printf T0p_S3cr3t1 > secret1.txt");
    assert_script_run("podman secret create secret1 secret1.txt",
        fail_message => "Error creating secret from file", timeout => 60);
    record_info("secret inspect file", script_output("podman secret inspect secret1"));

    # Create a secret2 from CLI and inspect it
    record_info("secret create CLI", "Create a new secret directly from CLI");
    assert_script_run("printf T0p_S3cr3t2 | podman secret create secret2 -",
        fail_message => "Error creating secret from CLI", timeout => 60);
    record_info("secret inspect CLI", script_output("podman secret inspect secret2"));

    # "podman secret exists" was added to podman 4.5.0 according to
    # https://github.com/containers/podman/blob/main/RELEASE_NOTES.md#450
    if (version->parse($podman_version) >= version->parse('4.5.0')) {
        # Check if secret exists
        record_info("secret exists", "In Podman, check that each created secret exists");
        assert_script_run("podman secret exists secret1",
            fail_message => "Error checking if secret exists");
        assert_script_run("podman secret exists secret2",
            fail_message => "Error checking if secret exists");
        # This secret3 does not exist and thus `secret exists` must return 1
        assert_script_run("! podman secret exists secret3",
            fail_message => "Error checking that secret doesn't exist");
    }

    # List all secrets
    record_info("secret ls", script_output("podman secret ls"));

    # Run a container passing secret1 as default and secret2 as an env variable
    record_info("Access secrets");
    script_retry("podman pull registry.opensuse.org/opensuse/bci/bci-busybox:latest",
        retry => 3, delay => 10, timeout => 120);
    validate_script_output("podman run --name secret-test --secret secret1 --secret secret2,type=env,target=TOP_SECRET2 bci-busybox:latest /bin/sh -c 'cat /run/secrets/secret1; echo; printenv TOP_SECRET2'", sub { m/T0p_S3cr3t1\nT0p_S3cr3t2/ });

    # Commit the container and check that the secrets are not in it
    record_info("Commit cont", "Commit container secret-test");
    assert_script_run("podman commit secret-test secret-test-image");
    assert_script_run("podman rm secret-test");
    $output = script_output("podman run --name secret-test secret-test-image:latest 'cat /run/secrets/secret1 & printenv TOP_SECRET2'", proceed_on_failure => 1);
    die("Secret commited") if ($output =~ m/T0p_S3cr3t1|T0p_S3cr3t2/);

    # Remove secrets
    record_info("secret rm", "Remove all secrets created");
    assert_script_run("podman secret rm secret1 secret2");
    die("Secrets have not been deleted")
      if (script_output("podman secret ls --quiet"));

    $engine->cleanup_system_host();
}

1;
