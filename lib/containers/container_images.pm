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

our @EXPORT = qw(build_container_image build_with_zypper_docker build_with_sle2docker test_opensuse_based_image);

# Build any container image using a basic Dockerfile
sub build_container_image {
    my %args    = @_;
    my $image   = $args{image};
    my $runtime = $args{runtime};

    die 'Argument $image not provided!'   unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

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
    my %args    = @_;
    my $image   = $args{image};
    my $runtime = $args{runtime};

    my $distri  = $args{distri}  //= get_required_var("DISTRI");
    my $version = $args{version} //= get_required_var("VERSION");

    die 'Argument $image not provided!'   unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

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

1;
