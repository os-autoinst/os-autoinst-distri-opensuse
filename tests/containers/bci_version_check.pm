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
use version_utils;
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
    if ($engines =~ /podman|k3s/) {
        $engine = 'podman';
        return if is_sle("=12-SP5", get_var("HOST_VERSION", get_required_var("VERSION")));    # podman is not available on 12-SP5.
    } elsif ($engines =~ /docker/) {
        $engine = 'docker';
    } else {
        die('No valid container engines defined in CONTAINER_RUNTIMES variable!');
    }

    # Avoid unnecessary load on IBS by holding back all test runs except 15-SP7, so that registry.suse.de can load the images into the cache
    # This is a temporary workaround until https://progress.opensuse.org/issues/189813 is done.
    sleep(150 + rand(150)) unless (get_var("CASEDIR") || check_var('HOST_VERSION', '15-SP7'));

    die "Pulling container image '$image' timed out. Likely a new build is already being prepared. Look for a new build and ignore this test run.\n"
      if script_run("timeout 3600 $engine pull -q $image", timeout => 3600 + 30) == 124;
    script_retry("$engine pull -q $image", timeout => 3600, delay => 60, retry => 2);
    record_info('Inspect', script_output("$engine inspect $image"));

    if ($build && $build ne 'UNKNOWN') {
        my $reference = script_output(qq($engine inspect --type image $image | jq -r '.[0].Config.Labels."org.opensuse.reference"'));
        # Note: Both lines are aligned, thus the additional space
        record_info('builds', "CONTAINER_IMAGE_BUILD:  $build\norg.opensuse.reference: $reference");
        die('Missmatch in image build number. The image build number is different than the one triggered by the container bot!') if ($reference !~ /$buildrelease$/);
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
