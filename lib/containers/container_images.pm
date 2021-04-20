# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Functionality concerning the testing of container images
# Maintainer: George Gkioulis <ggkioulis@suse.com>

package containers::container_images;

use base Exporter;
use Exporter;

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use version_utils;
use version;
use containers::utils;

our @EXPORT = qw(build_container_image build_with_zypper_docker build_with_sle2docker
  test_opensuse_based_image exec_on_container ensure_container_rpm_updates test_containered_app
  test_zypper_on_container verify_userid_on_container);

# Build any container image using a basic Dockerfile. Not applicable for buildah builds
sub build_container_image {
    my %args    = @_;
    my $image   = $args{image};
    my $runtime = $args{runtime};

    die 'Argument $image not provided!'   unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

    my $dir = "~/sle_base_image/docker_build";

    record_info("Building $image", "Building $image using $runtime");

    assert_script_run("mkdir -p $dir");
    assert_script_run("cd $dir");

    # Create basic Dockerfile
    assert_script_run("echo -e 'FROM $image\\nENV WORLD_VAR Arda' > Dockerfile");

    # Build the image
    assert_script_run("$runtime build -t dockerfile_derived .");
    assert_script_run("cd");

    assert_script_run("$runtime run --entrypoint 'printenv' dockerfile_derived WORLD_VAR | grep Arda");
    assert_script_run("$runtime images");
}

=head2 test_containered_app

 test_containered_app($runtime, [$buildah], $dockerfile, $base);

Create a container using a C<dockerfile> and run smoke test against that.
 C<base> can be used to setup base repo in the dockerfile in case that the file
does not have a defined one.

The main container runtimes do not need C<buildah> variable in general, unless
you want to build the image with buildah but run it with $<runtime>

=cut
sub test_containered_app {
    my %args       = @_;
    my $runtime    = $args{runtime};
    my $buildah    = $args{buildah} // 0;
    my $dockerfile = $args{dockerfile};
    my $base       = $args{base};

    die "You must define the runtime!"    unless $runtime;
    die "You must define the Dockerfile!" unless $dockerfile;

    my $dir = "/root/containerapp";

    # Setup the environment
    container_set_up("$dir", $dockerfile, $base);

    # Build the image
    $buildah ? build_img("$dir", 'buildah') : build_img("$dir", $runtime);
    if ($runtime eq 'docker' && $buildah) {
        assert_script_run "buildah push myapp docker-daemon:myapp:latest";
        script_run "$runtime images";
    }
    # Run the built image
    test_built_img($runtime);
}

# Build a sle container image using zypper_docker
sub build_with_zypper_docker {
    my %args          = @_;
    my $image         = $args{image};
    my $runtime       = $args{runtime};
    my $derived_image = "zypper_docker_derived";

    my $distri  = $args{distri}  //= get_required_var("DISTRI");
    my $version = $args{version} //= get_required_var("VERSION");

    die 'Argument $image not provided!'   unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

    my ($host_version,  $host_sp,  $host_id)  = get_os_release();
    my ($image_version, $image_sp, $image_id) = get_os_release("$runtime run $image");

    # The zypper-docker works only on openSUSE or on SLE based image on SLE host
    unless (($host_id =~ 'sles' && $image_id =~ 'sles') || $image_id =~ 'opensuse') {
        record_info 'Warning!', 'The zypper-docker only works for openSUSE based images and SLE based images on SLE host.';
        return;
    }

    # zypper docker can only update image if version is same as SUT
    if ($distri eq 'sle') {
        my $pretty_version = $version =~ s/-SP/ SP/r;
        my $betaversion    = get_var('BETA') ? '\s\([^)]+\)' : '';
        validate_script_output("$runtime run --entrypoint '/bin/bash' --rm $image -c 'cat /etc/os-release'",
            sub { /"SUSE Linux Enterprise Server ${pretty_version}${betaversion}"/ });
    } else {
        $version =~ s/^Jump://i;
        validate_script_output qq{$runtime container run --entrypoint '/bin/bash' --rm $image -c 'cat /etc/os-release'}, sub { /PRETTY_NAME="openSUSE (Leap )?${version}.*"/ };
    }

    zypper_call("in zypper-docker") if (script_run("which zypper-docker") != 0);
    assert_script_run("zypper-docker list-updates $image",      240);
    assert_script_run("zypper-docker up $image $derived_image", timeout => 160);

    # If zypper-docker list-updates lists no updates then derived image was successfully updated
    assert_script_run("zypper-docker list-updates $derived_image | grep 'No updates found'", 240);

    my $local_images_list = script_output("$runtime image ls");
    die("$runtime $derived_image not found") unless ($local_images_list =~ $derived_image);

    record_info("Testing derived", "Derived image: $derived_image");
    test_opensuse_based_image(image => $derived_image, runtime => $runtime);
}

sub test_opensuse_based_image {
    my %args    = @_;
    my $image   = $args{image};
    my $runtime = $args{runtime};

    my $distri  = $args{distri}  //= get_required_var("DISTRI");
    my $version = $args{version} //= get_required_var("VERSION");

    die 'Argument $image not provided!'   unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

    my ($host_version, $host_sp, $host_id) = get_os_release();
    my ($image_version, $image_sp, $image_id);

    if ($runtime =~ /buildah/) {
        ($image_version, $image_sp, $image_id) = get_os_release("$runtime run $image");
    } else {
        ($image_version, $image_sp, $image_id) = get_os_release("$runtime run --entrypoint '' $image");
    }
    record_info "Host",  "Host has '$host_version', '$host_sp', '$host_id' in /etc/os-release";
    record_info "Image", "Image has '$image_version', '$image_sp', '$image_id' in /etc/os-release";

    $version = 'Tumbleweed' if ($version =~ /^Staging:/);

    if ($image_id =~ 'sles') {
        if ($host_id =~ 'sles') {
            my $pretty_version = $version =~ s/-SP/ SP/r;
            my $betaversion    = get_var('BETA') ? '\s\([^)]+\)' : '';
            record_info "Validating", "Validating That $image has $pretty_version on /etc/os-release";
            if ($runtime =~ /buildah/) {
                validate_script_output("$runtime run $image grep PRETTY_NAME /etc/os-release | cut -d= -f2",
                    sub { /"SUSE Linux Enterprise Server ${pretty_version}${betaversion}"/ });
            } else {
                # zypper-docker changes the layout of the image
                validate_script_output("$runtime run --entrypoint /bin/bash $image -c 'grep PRETTY_NAME /etc/os-release' | cut -d= -f2",
                    sub { /"SUSE Linux Enterprise Server ${pretty_version}${betaversion}"/ });
            }

            # SUSEConnect zypper service is supported only on SLE based image on SLE host
            my $plugin = '/usr/lib/zypp/plugins/services/container-suseconnect-zypp';
            if ($runtime =~ /buildah/) {
                assert_script_run "$runtime run -t $image -- $plugin -v";
                script_run "$runtime run -t $image -- $plugin lp", 420;
                script_run "$runtime run -t $image -- $plugin lm", 420;
            } else {
                assert_script_run "$runtime container run --entrypoint '/bin/bash' --rm $image -c '$plugin -v'";
                script_run "$runtime container run --entrypoint '/bin/bash' --rm $image -c '$plugin lp'", 420;
                script_run "$runtime container run --entrypoint '/bin/bash' --rm $image -c '$plugin lm'", 420;
            }
        } else {
            record_info "non-SLE host", "This host ($host_id) does not support zypper service";
        }
    } else {
        $version =~ s/^Jump://i;
        if ($runtime =~ /buildah/) {
            if (script_output("$runtime run $image grep PRETTY_NAME /etc/os-release") =~ /WARN.+from \"\/etc\/containers\/mounts.conf\" doesn\'t exist, skipping/) {
                record_soft_failure "bcs#1183482 - libcontainers-common contains SLE files on TW";
            }
            else {
                validate_script_output("$runtime run $image grep PRETTY_NAME /etc/os-release | cut -d= -f2",
                    sub { /PRETTY_NAME="openSUSE (Leap )?${version}.*"/ });
            }
        }
        else {
            validate_script_output qq{$runtime container run --entrypoint '/bin/bash' --rm $image -c 'cat /etc/os-release'}, sub { /PRETTY_NAME="openSUSE (Leap )?${version}.*"/ };
        }
    }

    # Zypper is supported only on openSUSE or on SLE based image on SLE host
    if (($host_id =~ 'sles' && $image_id =~ 'sles') || $image_id =~ 'opensuse') {
        test_zypper_on_container($runtime, $image);
    }
}

sub verify_userid_on_container {
    my ($runtime, $image, $start_id) = @_;
    my $huser_id = script_output "echo \$UID";
    record_info "host uid",          "$huser_id";
    record_info "root default user", "rootless mode process runs with the default container user(root)";
    my $cid = script_output "$runtime run -d --rm --name test1 $image sleep infinity";
    validate_script_output "$runtime top $cid user huser", sub { /root\s+1000/ };
    validate_script_output "$runtime top $cid capeff",     sub { /setuid/i };

    record_info "non-root user", "process runs under the range of subuids assigned for regular user";
    $cid = script_output "$runtime run -d --rm --name test2 --user 1000 $image sleep infinity";
    my $id = $start_id + $huser_id - 1;
    validate_script_output "$runtime top $cid user huser", sub { /1000\s+${id}/ };
    validate_script_output "$runtime top $cid capeff",     sub { /none/ };

    record_info "root with keep-id", "the default user(root) starts process with the same uid as host user";
    $cid = script_output "$runtime run -d --rm --userns keep-id $image sleep infinity";
    # Remove once the softfail removed. it is just checks the user's mapped uid
    validate_script_output "$runtime exec -it $cid cat /proc/self/uid_map", sub { /1000/ };
    if (is_sle) {
        validate_script_output "$runtime top $cid user huser", sub { /bernhard\s+bernhard/ };
        validate_script_output "$runtime top $cid capeff",     sub { /setuid/i };
    }
    else {
        record_soft_failure "bsc#1182428 - Issue with nsenter from podman-top";
    }
}

sub test_zypper_on_container {
    my ($runtime, $image) = @_;

    die 'Argument $image not provided!'   unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

    # zypper lr
    assert_script_run("$runtime run $image zypper lr -s", 120);

    if ($runtime =~ /buildah/) {
        # zypper ref
        assert_script_run("$runtime run $image -- zypper -v ref | grep \"All repositories have been refreshed\"", 120);

        # Create new image and remove the working container
        assert_script_run("$runtime commit --rm $image refreshed", 120);

        # Verify the new image works
        assert_script_run("$runtime run \$($runtime from refreshed) -- zypper -v ref | grep \"All repositories have been refreshed\" ", 120);
    } else {
        # zypper ref
        assert_script_run("$runtime run --name refreshed $image sh -c 'zypper -v ref | grep \"All repositories have been refreshed\"'", 120);

        # Commit the image
        assert_script_run("$runtime commit refreshed refreshed-image", 120);

        # Remove it
        assert_script_run("$runtime rm refreshed", 120);

        # Verify the image works
        assert_script_run("$runtime run --rm refreshed-image sh -c 'zypper -v ref | grep \"All repositories have been refreshed\"'", 120);
    }
    record_info "The End", "zypper test completed";
}

sub ensure_container_rpm_updates {
    my $diff_file     = shift;
    my $regex2match   = qr/^-(?<package>[^\s]+)\s+(\d+\.?\d+?)+-(?P<update_version>\d+\.?\d+?\.\d+\b).*\s+(\d+\.?\d+?)+-(?P<stable_version>\d+\.?\d+?\.\d+\b)/;
    my $regex2zerorpm = qr/^Version differences: None$/;
    my $context       = script_output "cat $diff_file";
    open(my $data, '<', \$context) or die "problem with $diff_file argument", $!;
    while (my $line = <$data>) {
        if ($line =~ $regex2match) {
            # Use of Dotted-Decimal-Versions. Do not remove 'v' prefix
            my $updated_v = version->parse("v$+{update_version}");
            my $stable_v  = version->parse("v$+{stable_version}");
            record_info("checking... $+{package}", "$+{package} $stable_v to $updated_v");
            if ($stable_v eq 'v52.1' && $updated_v eq 'v49.1') {
                record_soft_failure('poo#91422');
                last;
            }
            die "$+{package} $stable_v is not updated to $updated_v" unless ($updated_v > $stable_v);
        } elsif ($line =~ $regex2zerorpm) {
            record_info("No Update found", "no updates found between rpm versions");
            last;
        }
    }
    close($data);
}

sub exec_on_container {
    my ($image, $runtime, $command, $timeout) = @_;
    $timeout //= 120;
    assert_script_run("$runtime run --rm $image $command", $timeout);
}

1;
