# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman network
# Summary: Test podman network
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils;
use containers::utils qw(get_docker_version get_podman_version);

my $test_dir = "test_dir";

sub run {
    my ($self, $args) = @_;
    my $runtime = $args->{runtime};

    select_serial_terminal();

    my $docker_version = "";
    my $podman_version = "";
    if ($runtime eq "docker") {
        $docker_version = get_docker_version();
    } elsif ($runtime eq "podman") {
        $podman_version = get_podman_version();
    } else {
        return;
    }

    # From https://docs.docker.com/storage/bind-mounts/
    # The --mount flag does not support z or Z options for modifying selinux labels.
    my $Z = $runtime eq "podman" ? ",Z" : "";

    my $test_file = "test_file";
    my $test_image = "test_image";
    my $test_container = "test_container";
    my $test_volume = "test_volume";

    assert_script_run("mkdir -p $test_dir");

    # Create Dockerfile with VOLUME defined
    assert_script_run("echo -e 'FROM registry.opensuse.org/opensuse/bci/bci-busybox:latest\\nVOLUME /$test_dir' > $test_dir/Dockerfile");

    # Build image
    assert_script_run("$runtime build -t $test_image -f $test_dir/Dockerfile $test_dir/");

    # Test --volumes-from
    # Case 1: Check that the volume from container is visible in another container
    assert_script_run("$runtime run -d --name $test_container $test_image");
    assert_script_run("$runtime run --rm --volumes-from $test_container $test_image ls /$test_dir");
    assert_script_run("$runtime rm -vf $test_container");

    # Case 2: Check that the volume from container is visible in another container, but the
    # first container is mounting it in the directory specified as VOLUME in the Dockerfile
    assert_script_run("touch $test_dir/$test_file");
    assert_script_run("$runtime run -d --name $test_container -v \$PWD/$test_dir:/$test_dir:Z $test_image");
    # NOTE: When https://github.com/containers/podman/issues/19529 is solved we must add a version check here
    my $ret = script_run("$runtime run --rm --volumes-from $test_container $test_image ls /$test_dir/$test_file");
    if ($ret != 0) {
        if ($runtime eq "podman" && (version->parse($podman_version) < version->parse('4.7.0'))) {
            record_soft_failure("gh#containers/podman#19529 - Unexpected error with --volumes-from") if ($ret != 0 && $runtime == "podman");
        } else {
            die("--volumes-from failed");
        }
    }

    assert_script_run("$runtime rm -vf $test_container");

    # Test --volume option with directory (read-only)
    assert_script_run("! $runtime run --rm --volume \$PWD/$test_dir:/$test_dir:ro,Z $test_image rm /$test_dir/$test_file");
    assert_script_run("test -f $test_dir/$test_file");

    # Equivalent --mount option to above
    assert_script_run("! $runtime run --rm --mount type=bind,source=\$PWD/$test_dir,destination=/$test_dir,readonly$Z $test_image rm /$test_dir/$test_file");
    assert_script_run("test -f $test_dir/$test_file");

    assert_script_run("rm $test_dir/$test_file");

    # Test --volume option with directory (read-write)
    assert_script_run("$runtime run --rm --volume \$PWD/$test_dir:/$test_dir:Z $test_image touch /$test_dir/$test_file");
    assert_script_run("test -f $test_dir/$test_file");

    assert_script_run("rm $test_dir/$test_file");

    # Equivalent --mount option to above
    assert_script_run("$runtime run --rm --mount type=bind,source=\$PWD/$test_dir,destination=/${test_dir}$Z $test_image touch /$test_dir/$test_file");
    assert_script_run("test -f $test_dir/$test_file");

    # Test volume subcommands
    assert_script_run("$runtime volume create $test_volume");
    assert_script_run("$runtime volume ls --format '{{.Name}}' | grep -Fx $test_volume");
    assert_script_run("$runtime volume inspect --format '{{.Name}}' $test_volume | grep -Fx $test_volume");
    # Other subcommands supported only by podman: mount unmount reload
    if ($runtime eq "podman") {
        # https://github.com/containers/podman/blob/main/RELEASE_NOTES.md#310
        if (version->parse($podman_version) > version->parse('3.1.0')) {
            assert_script_run("$runtime volume exists $test_volume");
        }
        # https://github.com/containers/podman/blob/main/RELEASE_NOTES.md#340
        if (version->parse($podman_version) > version->parse('3.4.0')) {
            assert_script_run("tar cf - $test_dir | $runtime volume import $test_volume -");
            assert_script_run("$runtime volume export $test_volume | tar tf - | grep -Fx $test_dir/$test_file");
        }
    }
    assert_script_run("$runtime volume rm $test_volume");
    assert_script_run("! $runtime volume inspect $test_volume");

    for (my $i = 1; $i <= 10; $i++) {
        assert_script_run("$runtime volume create $test_volume");

        # Test --volume option with volume (read-write)
        assert_script_run("$runtime run --rm --volume $test_volume:/$test_dir $test_image touch /$test_dir/$test_file");
        assert_script_run("test -f $test_dir/$test_file");

        # Equivalent --mount option to above
        # NOTE: ",Z" in --mount is known to work on 4.6.0+ but not 4.4.4
        my $optionalZ = ($runtime eq "podman" && version->parse($podman_version) < version->parse('4.6.0')) ? "" : $Z;
        assert_script_run("$runtime run --rm --mount type=volume,source=$test_volume,destination=/$test_dir$optionalZ $test_image touch /$test_dir/$test_file");

        # Test --volume option with volume (read-only)
        assert_script_run("! $runtime run --rm --volume $test_volume:/$test_dir:ro $test_image rm /$test_dir/$test_file");
        assert_script_run("test -f $test_dir/$test_file");

        # Equivalent --mount option to above
        assert_script_run("! $runtime run --rm --mount type=volume,source=$test_volume,destination=/$test_dir,readonly$optionalZ $test_image rm /$test_dir/$test_file");

        assert_script_run("$runtime volume rm $test_volume");
        assert_script_run("! $runtime volume inspect $test_volume");
    }

    my $all = "";
    if ($runtime eq "docker") {
        $all = "-a";
        # The -a option to docker volume prune was added to 23.0.5 according to:
        # https://docs.docker.com/engine/release-notes/23.0/#2305
        return if (version->parse($docker_version) < version->parse('23.0.5'));
    }
    # Create a dangling (not used by any container) volume and test its removal
    assert_script_run("$runtime volume create $test_volume");
    assert_script_run("$runtime volume prune $all -f | grep -Fx $test_volume");
    assert_script_run("! $runtime volume inspect $test_volume");
    assert_script_run("[ \$($runtime volume ls --quiet --filter dangling=true | wc -l\) -eq 0 ]");
}

1;

sub cleanup() {
    script_run("rm -rf $test_dir");
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup();
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = @_;
    cleanup();
    $self->SUPER::post_run_hook;
}
