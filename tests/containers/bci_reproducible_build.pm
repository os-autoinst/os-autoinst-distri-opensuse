# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Checks image hashes for reproducible builds
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use JSON qw(decode_json);


sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    # This module must not block a release. Report failures as softfailure (see poo#199730)
    eval {

        # We compare the container in the test pipeline against an external reference.
        # Naming convention: test container is the container in ToTest, reference is the reference container from the adjacent reference repository
        my $con = get_required_var('CONTAINER_IMAGE_TO_TEST');
        my $ref = get_required_var('CONTAINER_REPRODUCIBLE_IMAGE_TO_TEST');

        # Ensure the build is the same
        my $build_con = get_container_labels($con)->{'org.opensuse.reference'};
        my $build_ref = get_container_labels($ref)->{'org.opensuse.reference'};
        record_info("Builds", "Container: $build_con\nReference: $build_ref");
        record_info("Build mismatch", "Mismatch in build number between test container and reference", result => 'fail') unless ($build_con eq $build_ref);

        # Check for reproducible builds by comparing the hash of the root layer (i.e. the main file system layer)
        my @layers1 = get_container_layers($con);
        my @layers2 = get_container_layers($ref);
        my $info = "Test container layers:\n" . join("\n", @layers1) . "\n\nReference container layers:\n" . join("\n", @layers2);
        record_info("Layers", $info);
        die "Root layer hashes are not the same" unless ($layers1[0] eq $layers2[0]);
    };
    if ($@) {
        record_soft_failure("Reproducible build check failed (poo#199730)");
        # Give it an additional red bubble in the openQA WebUI for better visibility
        record_info('Failed', $@, result => 'fail');
    }
}

# Get an array of all hash values of all layers of a given container image (by name or by image id)
# Example output: ['sha256:bf86d5278b74ed1a2bb97a156d8285c7a5039acb87d79844908415b3945420b3', 'sha256:616ae5320e5c6bd964730a45f3a6ef85baa82b2b885ae2709b6aaf3da58f9407']
sub get_container_layers {
    my ($container) = @_;

    # Return the hash of the top filesystem layer
    my $image = decode_json(script_output("skopeo inspect docker://$container"));
    return @{$image->{Layers}};
}

# Get hash of the Labels of a given container (by name or by image id)
sub get_container_labels {
    my ($container) = @_;

    # Return the hash of the top RootFS layer
    my $image = decode_json(script_output("skopeo inspect docker://$container"));
    return $image->{Labels};
}

sub test_flags {
    return {fatal => 0, no_rollback => 1};
}

1;
