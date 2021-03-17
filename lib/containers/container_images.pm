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
    my ($runtime, $image) = @_;

    die 'Argument $image not provided!' unless $image;

    my $dockerfile_dir  = "~/sle_base_image/docker_build/";
    my $dockerfile_path = $dockerfile_dir . "Dockerfile";

    record_info("Building $image", "Building $image using " . $runtime->engine);

    assert_script_run("mkdir -p $dockerfile_dir");

    # Create basic Dockerfile
    assert_script_run("echo -e 'FROM $image\nENV WORLD_VAR Arda' > $dockerfile_path");

    # Build the image
    $runtime->build(dockerfile_path => $dockerfile_path, container_tag => 'dockerfile_derived');

    $runtime->_rt_assert_script_run("run --entrypoint 'printenv' dockerfile_derived WORLD_VAR | grep Arda");
    $runtime->enum_images();
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
    my ($runtime, %args) = @_;
    my $dockerfile = $args{dockerfile};
    my $base       = $args{base};
    my $buildah    = $args{buildah} // 0;
    my $registry   = $runtime->registry;

    die "You must define the Dockerfile!" unless $dockerfile;

    my $dir = "/root/containerapp";

    # Setup the environment
    container_set_up($dir, $dockerfile, $base);

    # Build the image
    assert_script_run("cd $dir");
    if ($runtime->is_buildah() || $args{buildah}) {
        $runtime->_rt_assert_script_run("bud -t myapp BuildTest");
    }
    else {
        $runtime->_rt_assert_script_run("image pull $registry/library/python:3", timeout => 300);
        $runtime->_rt_assert_script_run("tag $registry/library/python:3 python:3");
        $runtime->_rt_assert_script_run("build -t myapp BuildTest");
    }
    grep(/myapp/, $runtime->enum_images());
    if ($runtime->is_docker() && $args{buildah}) {
        assert_script_run "buildah push myapp docker-daemon:myapp:latest";
        $runtime->_rt_assert_script_run("images");
    }

    # Run the built image
    $runtime->engine = 'podman' if $runtime->is_buildah();
    assert_script_run("mkdir /root/templates");
    assert_script_run "curl -f -v " . data_url('containers/index.html') . " > /root/templates/index.html";
    $runtime->_rt_assert_script_run("run -dit -p 8888:5000 myapp www.google.com");
    sleep 5;
    $runtime->_rt_assert_script_run("ps -a");
    script_retry('curl http://localhost:8888/ | grep "Networking test shall pass"', delay => 5, retry => 6);
    assert_script_run("rm -rf /root/templates");
}

# Setup environment
sub container_set_up {
    my ($dir, $file, $base) = @_;
    die "You must define the directory!"  unless $dir;
    die "You must define the Dockerfile!" unless $file;
    my $basename_expected = script_run("grep baseimage_var $dir/BuildTest/$file");
    die "Base image name is required for $file" if !$basename_expected && $base;

    record_info "Dockerfile: $file";
    assert_script_run("mkdir -p $dir/BuildTest");
    assert_script_run "curl -f -v " . data_url('containers/app.py') . " > $dir/BuildTest/app.py";
    record_info('app.py', script_output("cat $dir/BuildTest/app.py"));
    assert_script_run "curl -f -v " . data_url("containers/$file") . " > $dir/BuildTest/Dockerfile";
    assert_script_run "sed -i 's,baseimage_var,$base,1' $dir/BuildTest/Dockerfile" if defined $base;
    record_info('Dockerfile', script_output("cat $dir/BuildTest/Dockerfile"));
    assert_script_run "curl -f -v " . data_url('containers/requirements.txt') . " > $dir/BuildTest/requirements.txt";
    record_info('requirements.txt', script_output("cat $dir/BuildTest/requirements.txt"));
    assert_script_run("mkdir -p $dir/BuildTest/templates");
    assert_script_run "curl -f -v " . data_url('containers/index.html') . " > $dir/BuildTest/templates/index.html";
}

# Build a sle container image using zypper_docker
sub build_with_zypper_docker {
    my ($runtime, %args) = @_;
    my $image         = $args{image};
    my $derived_image = "zypper_docker_derived";

    my $distri  = $args{distri}  //= get_required_var("DISTRI");
    my $version = $args{version} //= get_required_var("VERSION");

    die 'Argument $image not provided!' unless $image;

    my ($host_version,  $host_sp,  $host_id)  = get_os_release();
    my ($image_version, $image_sp, $image_id) = get_os_release($runtime->engine . " run $image");

    # The zypper-docker works only on openSUSE or on SLE based image on SLE host
    unless (($host_id =~ 'sles' && $image_id =~ 'sles') || $image_id =~ 'opensuse') {
        record_info 'The zypper-docker only works for openSUSE based images and SLE based images on SLE host.';
        return;
    }

    # zypper docker can only update image if version is same as SUT
    if ($distri eq 'sle') {
        my $pretty_version = $version =~ s/-SP/ SP/r;
        my $betaversion    = get_var('BETA') ? '\s\([^)]+\)' : '';
        $runtime->_rt_validate_script_output("run --entrypoint '/bin/bash' --rm $image -c 'cat /etc/os-release'",
            sub { /"SUSE Linux Enterprise Server ${pretty_version}${betaversion}"/ });
    } else {
        $version =~ s/^Jump://i;
        $runtime->_rt_validate_script_output("container run --entrypoint '/bin/bash' --rm $image -c 'cat /etc/os-release'", sub { /PRETTY_NAME="openSUSE (Leap )?${version}.*"/ });
    }

    zypper_call("in zypper-docker") if (script_run("which zypper-docker") != 0);
    assert_script_run("zypper-docker list-updates $image",      240);
    assert_script_run("zypper-docker up $image $derived_image", timeout => 160);

    # If zypper-docker list-updates lists no updates then derived image was successfully updated
    assert_script_run("zypper-docker list-updates $derived_image | grep 'No updates found'", 240);

    my $local_images_list = $runtime->_rt_script_output("image ls");
    die($runtime->engine . " $derived_image not found") unless ($local_images_list =~ $derived_image);

    record_info("Testing derived");
    test_opensuse_based_image($runtime, image => $derived_image);
}

sub test_opensuse_based_image {
    my ($runtime, %args) = @_;
    my $image = $args{image};

    my $distri  = $args{distri}  //= get_required_var("DISTRI");
    my $version = $args{version} //= get_required_var("VERSION");

    die 'Argument $image not provided!' unless $image;

    my ($host_version, $host_sp, $host_id) = get_os_release();
    my $entrypoint = $runtime->is_buildah() ? "" : "run --entrypoint ''";
    my ($image_version, $image_sp, $image_id) = get_os_release($runtime->_rt_script_output("run $entrypoint $image"));

    record_info "Host",  "Host has '$host_version', '$host_sp', '$host_id' in /etc/os-release";
    record_info "Image", "Image has '$image_version', '$image_sp', '$image_id' in /etc/os-release";

    $version = 'Tumbleweed' if ($version =~ /^Staging:/);

    if ($image_id =~ 'sles') {
        if ($host_id =~ 'sles') {
            my $pretty_version = $version =~ s/-SP/ SP/r;
            my $betaversion    = get_var('BETA') ? '\s\([^)]+\)' : '';
            record_info "Validating", "Validating That $image has $pretty_version on /etc/os-release";
            if ($runtime->is_buildah()) {
                $runtime->_rt_validate_script_output("run $image grep PRETTY_NAME /etc/os-release | cut -d= -f2",
                    sub { /"SUSE Linux Enterprise Server ${pretty_version}${betaversion}"/ });
            } else {
                # zypper-docker changes the layout of the image
                $runtime->_rt_validate_script_output("run --entrypoint /bin/bash $image -c 'grep PRETTY_NAME /etc/os-release' | cut -d= -f2",
                    sub { /"SUSE Linux Enterprise Server ${pretty_version}${betaversion}"/ });
            }

            # SUSEConnect zypper service is supported only on SLE based image on SLE host
            my $plugin = '/usr/lib/zypp/plugins/services/container-suseconnect-zypp';
            if ($runtime->is_buildah()) {
                $runtime->_rt_assert_script_run("run -t $image -- $plugin -v");
                $runtime->_rt_script_run("run -t $image -- $plugin lp", timeout => 420);
                $runtime->_rt_script_run("run -t $image -- $plugin lm", timeout => 420);
            } else {
                $runtime->_rt_assert_script_run("container run --entrypoint '/bin/bash' --rm $image -c '$plugin -v'");
                $runtime->_rt_script_run("container run --entrypoint '/bin/bash' --rm $image -c '$plugin lp'", timeout => 420);
                $runtime->_rt_script_run("container run --entrypoint '/bin/bash' --rm $image -c '$plugin lm'", timeout => 420);
            }
        } else {
            record_info "non-SLE host", "This host ($host_id) does not support zypper service";
        }
    } else {
        $version =~ s/^Jump://i;
        if ($runtime->is_buildah()) {
            if ($runtime->_rt_script_output("run $image grep PRETTY_NAME /etc/os-release") =~ /WARN.+from \"\/etc\/containers\/mounts.conf\" doesn\'t exist, skipping/) {
                record_soft_failure "bcs#1183482 - libcontainers-common contains SLE files on TW";
            }
            else {
                $runtime->_rt_validate_script_output("run $image grep PRETTY_NAME /etc/os-release | cut -d= -f2", sub { /PRETTY_NAME="openSUSE (Leap )?${version}.*"/ });
            }
        }
        else {
            $runtime->_rt_validate_script_output("container run --entrypoint '/bin/bash' --rm $image -c 'cat /etc/os-release'", sub { /PRETTY_NAME="openSUSE (Leap )?${version}.*"/ });
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
    my $cid = $runtime->_rt_script_output("run -d --rm --name test1 $image sleep infinity");
    $runtime->_rt_validate_script_output("top $cid user huser", sub { /root\s+1000/ });
    $runtime->_rt_validate_script_output("top $cid capeff",     sub { /setuid/i });

    record_info "non-root user", "process runs under the range of subuids assigned for regular user";
    $cid = $runtime->_rt_script_output("run -d --rm --name test2 --user 1000 $image sleep infinity");
    my $id = $start_id + $huser_id - 1;
    $runtime->_rt_validate_script_output("top $cid user huser", sub { /1000\s+${id}/ });
    $runtime->_rt_validate_script_output("top $cid capeff",     sub { /none/ });

    record_info "root with keep-id", "the default user(root) starts process with the same uid as host user";
    $cid = $runtime->_rt_script_output("run -d --rm --userns keep-id $image sleep infinity");
    # Remove once the softfail removed. it is just checks the user's mapped uid
    $runtime->_rt_validate_script_output("exec -it $cid cat /proc/self/uid_map", sub { /1000/ });
    if (is_sle) {
        $runtime->_rt_validate_script_output("top $cid user huser", sub { /bernhard\s+bernhard/ });
        $runtime->_rt_validate_script_output("top $cid capeff",     sub { /setuid/i });
    }
    else {
        record_soft_failure "bsc#1182428 - Issue with nsenter from podman-top";
    }
}

sub test_zypper_on_container {
    my ($runtime, $image) = @_;
    my $engine = $runtime->engine;

    die 'Argument $image not provided!' unless $image;

    # zypper lr
    $runtime->_rt_assert_script_run("run $image zypper lr -s", timeout => 120);

    if ($runtime->is_buildah()) {
        # zypper ref
        $runtime->_rt_assert_script_run("run $image -- zypper -v ref | grep \"All repositories have been refreshed\"", timeout => 120);

        # Create new image and remove the working container
        $runtime->_rt_assert_script_run("commit --rm $image refreshed", timeout => 120);

        # Verify the new image works
        $runtime->_rt_assert_script_run("run \$($engine from refreshed) -- zypper -v ref | grep \"All repositories have been refreshed\" ", timeout => 120);
    } else {
        # zypper ref
        $runtime->_rt_assert_script_run("run --name refreshed $image sh -c 'zypper -v ref | grep \"All repositories have been refreshed\"'", timeout => 120);

        # Commit the image
        $runtime->_rt_assert_script_run("commit refreshed refreshed-image", timeout => 120);

        # Remove it
        $runtime->_rt_assert_script_run("rm refreshed", timeout => 120);

        # Verify the image works
        $runtime->exec_on_container("refreshed-image", "sh -c 'zypper -v ref | grep \"All repositories have been refreshed\"'", 120);
    }
    record_info "zypper test completed";
}

sub ensure_container_rpm_updates {
    my ($diff_file)   = @_;
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
            die "$+{package} $stable_v is not updated to $updated_v" unless ($updated_v > $stable_v);
        } elsif ($line =~ $regex2zerorpm) {
            record_info("No Update found", "no updates found between rpm versions");
            last;
        }
    }
    close($data);
}

1;
