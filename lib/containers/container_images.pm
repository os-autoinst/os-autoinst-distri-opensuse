# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Functionality concerning the testing of container images
# Maintainer: George Gkioulis <ggkioulis@suse.de>

package containers::container_images;

use base Exporter;
use Exporter;

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use version_utils;

our @EXPORT = qw(build_container_image build_with_zypper_docker build_with_sle2docker test_opensuse_based_image perform_container_diff);

# Build any container image using a basic Dockerfile
sub build_container_image {
    my $image   = shift;
    my $runtime = shift // "docker";

    my $dir = "/root/sle_base_image/docker_build";

    record_info("Building $image", "Building $image using $runtime");

    assert_script_run("mkdir -p $dir");
    assert_script_run("cd $dir");

    # Create basic Dockerfile
    assert_script_run("echo -e 'FROM $image\nENV WORLD_VAR Arda' > Dockerfile");

    # Build the image
    assert_script_run("$runtime build -t dockerfile_derived .");

    assert_script_run("$runtime run --entrypoint 'printenv' dockerfile_derived WORLD_VAR | grep Arda");
    assert_script_run("$runtime images");
}

# Build a sle container image using zypper_docker
sub build_with_zypper_docker {
}

# Build a sle image using sle2docker
sub build_with_sle2docker {
}

# Testing openSUSE based images
sub test_opensuse_based_image {
    my $image = $_[0];
    my ($name, $tag) = split(/:/, $image);
    $tag //= 'latest';

    my $runtime = $_[1] //= "docker";

    my $distri  = $_[2] //= get_required_var("DISTRI");
    my $version = $_[3] //= get_required_var("VERSION");

    # It is the right version
    if ($distri eq 'sle') {
        my $pretty_version = $version =~ s/-SP/ SP/r;
        validate_script_output("$runtime container run --entrypoint '/bin/bash' --rm $image -c 'cat /etc/os-release'", sub { /PRETTY_NAME="SUSE Linux Enterprise Server $pretty_version"/ });

        if (is_sle('=12-SP3', $version)) {
            my $plugin = '/usr/lib/zypp/plugins/services/container-suseconnect';
            assert_script_run "$runtime container run --entrypoint '/bin/bash' --rm $image -c '$plugin'";
        } else {
            my $plugin = '/usr/lib/zypp/plugins/services/container-suseconnect-zypp';
            assert_script_run "$runtime container run --entrypoint '/bin/bash' --rm $image -c '$plugin -v'";
            script_run "$runtime container run --entrypoint '/bin/bash' --rm $image -c '$plugin lp'", 420;
            script_run "$runtime container run --entrypoint '/bin/bash' --rm $image -c '$plugin lm'", 420;
        }
    } else {
        validate_script_output qq{$runtime container run --rm $image cat /etc/os-release}, sub { /PRETTY_NAME="openSUSE (Leap )?${version}.*"/ };
    }
    # zypper lr
    assert_script_run("$runtime run --rm $image zypper lr -s", 120);
    # zypper ref
    assert_script_run("$runtime run --name refreshed $image sh -c 'zypper -v ref | grep \"All repositories have been refreshed\"'", 120);
    # Commit the image
    assert_script_run("$runtime commit refreshed refreshed-image", 120);
    # Remove it
    assert_script_run("$runtime rm refreshed", 120);
    # Verify the image works
    assert_script_run("$runtime run --rm refreshed-image sh -c 'zypper -v ref | grep \"All repositories have been refreshed\"'", 120);
}

sub perform_container_diff {
    my $first  = $_[0];
    my $second = $_[1];

    # The container-diff is available only for x86_64 architecture
    # The registry.suse.de is not accessible from PC instances
    return unless check_var('ARCH', 'x86_64');

    zypper_call("install container-diff") if (script_run("which container-diff") != 0);

    # container-diff
    my $image_file = $first =~ s/\/|:/-/gr;
    if (script_run("docker pull $second", 600) == 0) {
        assert_script_run("container-diff diff daemon://$first daemon://$second --type=rpm --type=file --type=history > /tmp/container-diff-$image_file.txt", 300);
        upload_logs("/tmp/container-diff-$image_file.txt");
        assert_script_run("docker image rm $second");
    } else {
        record_soft_failure("Could not compare $first to $second as $second could not be downloaded");
    }
}

1;
