# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate container image
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal qw(select_serial_terminal);

sub run {
    my $container_type = get_required_var('TESTED_CONTAINER');
    my $k8s = get_var('K8S', 'null');

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    if ($container_type =~ /elemental/) {
        # Check container image with a simple command
        my $uri = get_required_var('ELEMENTAL3_IMAGE_TO_TEST');
        my $cmd = "podman run --rm $uri version";
        assert_script_run($cmd);

        # Record the command version
        record_info('Elemental Version', script_output($cmd));
    } elsif ($container_type =~ /$k8s/) {
        my $uri = get_required_var('K8S_IMAGE_TO_TEST');
        assert_script_run("podman pull $uri");
        my $rootfs = script_output("podman inspect -f '{{index .RootFS.Layers 0}}' $uri | cut -d: -f2");

        # Extract files from container
        assert_script_run("podman save $uri -o $k8s.tar");
        assert_script_run("tar xvf $k8s.tar");
        my $files_list = script_output("tar tf $rootfs.tar");

        # Record files list
        record_info("$k8s files", $files_list);

        unless ($files_list =~ m/install.sh/) {
            die("Missing installer!");
        }
    } else {
        die("Container type '$container_type' not supported!");
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
