# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Checks if the container version for the test run is still up-to-date
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use utils qw(zypper_call script_retry);
use db_utils qw(push_image_data_to_db);
use containers::common;
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    return unless (get_var('CONTAINER_IMAGE_TO_TEST') && get_var('CONTAINER_IMAGE_BUILD'));

    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');
    my $build = get_required_var('CONTAINER_IMAGE_BUILD');
    my @build = split(/-/, $build);
    my $buildrelease = $build[-1];

    record_info('IMAGE', $image);

    # If multiple engines are defined (e.g. CONTAINER_RUNTIMES=podman,docker), we use just one. podman is preferred.
    my $engines = get_required_var('CONTAINER_RUNTIMES');
    my $engine;
    if ($engines =~ /podman/) {
        $engine = 'podman';
    } elsif ($engines =~ /docker/) {
        $engine = 'docker';
    } else {
        die('No valid container engines defined in CONTAINER_RUNTIMES variable!');
    }

    script_retry("$engine pull -q $image", timeout => 300, delay => 60, retry => 3);
    record_info('Inspect', script_output("$engine inspect $image"));

    if ($build && $build ne 'UNKNOWN') {
        ## HOTFIX for 12-SP5 s390x. Delete this after a proper fix is applied. This should not be necessary!
        script_retry('zypper -n in jq', retry => 3) if (check_var('HOST_VERSION', '12-SP5'));

        my $reference = script_output(qq($engine inspect --type image $image | jq -r '.[0].Config.Labels."org.opensuse.reference"'));
        # Note: Both lines are aligned, thus the additional space
        record_info('builds', "CONTAINER_IMAGE_BUILD:  $build\norg.opensuse.reference: $reference");
        die('Missmatch in image build number. The image build number is different than the one triggered by the container bot!') if ($reference !~ /$buildrelease$/);
    }

    ## Pull container and collect container stats, but only for podman.
    # podman and docker collect the image size differently. To remain consistent we only collect the image size as reported by podman
    if ($image && get_var('IMAGE_STORE_DATA') && $engine =~ /podman/) {
        script_retry("podman pull -q $image", retry => 3, delay => 120);
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
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
