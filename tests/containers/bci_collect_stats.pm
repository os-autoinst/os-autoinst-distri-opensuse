# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: bci-tests stats collection
#
#   This module collects basic container stats and sends them to the k2 database
# Maintainer: QE-C team <qa-c@suse.de>


use strict;
use warnings;
use Mojo::Base qw(consoletest);
use utils qw(script_retry);
use db_utils qw(push_image_data_to_db);
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    die "IMAGE_STORE_DATA is not set" unless get_var('IMAGE_STORE_DATA');    # Failsafe

    # podman and docker collect the image size differently. To remain consistent we only collect the image size as reported by podman
    my $engines = get_required_var('CONTAINER_RUNTIMES');
    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');
    return unless ($engines =~ /podman/);

    script_retry("podman pull -q $image", timeout => 300, retry => 3, delay => 120);
    my $size_mb = script_output("podman inspect --format \"{{.VirtualSize}}\" $image") / 1000000;
    my %args;
    $args{arch} = get_required_var('ARCH');
    $args{distri} = 'bci';
    $args{flavor} = get_required_var('BCI_IMAGE_NAME');
    $args{flavor} =~ s/^bci-//;    # Remove optional bci prefix from the image name because the distri already determines that this is bci.
    $args{type} = 'VirtualSize';
    $args{version} = get_required_var('VERSION');
    $args{build} = get_required_var('BUILD');
    push_image_data_to_db('containers', $image, $size_mb, %args);
}

1;
