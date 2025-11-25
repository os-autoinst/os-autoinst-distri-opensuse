# SUSE's openQA tests
#
# Copyright 2020-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Functionality concerning the testing of container images
# Maintainer: qa-c team <qa-c@suse.de>

package containers::container_images;

use base Exporter;
use Exporter;

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use version_utils;
use Utils::Architectures;
use containers::utils;
use containers::common qw(test_container_image is_unreleased_sle);

our @EXPORT = qw(test_opensuse_based_image ensure_container_rpm_updates build_and_run_image test_zypper_on_container);

=head2 build_and_run_image

 build_and_run_image($runtime, [$buildah], $dockerfile, $base);

Create a container using a C<dockerfile> and check if the container can be accessed
via http queries. The container must be accessible on http://localhost:8888 and
return the string "The test shall pass".
 C<base> can be used to setup base repo in the dockerfile in case that the file
does not have a defined one. If not defined, the Dockerfile must contain a valid
FROM statement.

The main container runtimes do not need C<buildah> variable in general, unless
you want to build the image with buildah but run it with $<runtime>

=cut

sub build_and_run_image {
    my %args = @_;
    my $runtime = $args{runtime};
    my $builder = $args{builder} ? $args{builder} : $runtime;
    my $dockerfile = $args{dockerfile} // 'Dockerfile';
    my $base = $args{base};

    die "undefined runtime" unless $runtime;
    die "undefined dockerfile" unless $dockerfile;

    my $dir = "/var/tmp/containerapp";

    # Setup the environment
    record_info('Run image', "Base:       $base\nDockerfile: $dockerfile\nRuntime:    $runtime->{runtime}");
    assert_script_run("mkdir -p $dir/BuildTest");
    assert_script_run("curl -f -v " . data_url("containers/$dockerfile") . " -o $dir/BuildTest/Dockerfile");
    if ($dockerfile eq 'Dockerfile.python3') {
        # 'Dockerfile.python3' has additional requirements that need to be downloaded
        assert_script_run("curl -fv " . data_url('containers/www.py') . " -o $dir/BuildTest/www.py");
        assert_script_run("chmod 755 $dir/BuildTest/www.py");
    } else {
        assert_script_run("curl -fv " . data_url('containers/index.html') . " -o $dir/BuildTest/index.html");
    }
    file_content_replace("$dir/BuildTest/Dockerfile", baseimage_var => $base) if defined $base;

    $builder->build($dir . "/BuildTest", "myapp", timeout => 1200);
    assert_script_run("rm -rf $dir");
    script_run("$runtime images");
    assert_script_run("$runtime images --all | grep myapp");

    if ($runtime->runtime eq 'docker' && $builder->runtime eq 'buildah') {
        assert_script_run "buildah push myapp docker-daemon:myapp:latest";
        script_run "$runtime images";
    }

    # Test that we can execute programs in the container and test container's variables
    assert_script_run("$runtime run --rm --entrypoint 'printenv' myapp WORLD_VAR | grep Arda");
    assert_script_run("$runtime run -d --name myapp -p 8888:80 myapp");
    validate_script_output_retry("$runtime ps -a", sub { m/myapp/ }, retry => 3, delay => 5, timeout => 300);
    assert_script_run("$runtime logs myapp");

    # Test that the exported port is reachable
    validate_script_output_retry("curl -s http://localhost:8888/", sub { m/The test shall pass/ }, retry => 5, delay => 60, timeout => 300);

    # Cleanup
    assert_script_run("$runtime stop myapp");
    assert_script_run("$runtime rm myapp");
}

sub test_opensuse_based_image {
    my %args = @_;
    my $image = $args{image};
    my $runtime = $args{runtime};

    my $distri = $args{distri} // get_required_var("DISTRI");
    my $version = $args{version} // get_required_var("VERSION");
    my $beta = $args{beta} // get_var('BETA', 0);

    die 'Argument $image not provided!' unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

    my ($host_version, $host_sp, $host_id) = get_os_release();
    my ($image_version, $image_sp, $image_id) = get_os_release("$runtime run --rm --entrypoint '' $image");

    record_info "Host", "Host has '$host_version', '$host_sp', '$host_id' in /etc/os-release";
    record_info "Image", "Image has '$image_version', '$image_sp', '$image_id' in /etc/os-release";

    $version = 'Tumbleweed' if ($version =~ /^Staging:/);

    if ($image_id =~ 'sles') {
        if ($host_id =~ 'sles') {
            my $pretty_version = $version =~ s/-SP/ SP/r;
            my $betaversion = $beta ? '\s\([^)]+\)' : '';
            record_info "Validating", "Validating That $image has $pretty_version on /etc/os-release";
            validate_script_output("$runtime run --rm --entrypoint /bin/bash $image -c 'cat /etc/os-release' | grep PRETTY_NAME | cut -d= -f2",
                sub { /"SUSE Linux Enterprise Server ${pretty_version}${betaversion}"/ });

            # SUSEConnect zypper service is supported only on SLE based image on SLE host
            unless (is_unreleased_sle) {
                my $cmd = "container-suseconnect";
                record_info("$cmd version", script_output("$runtime run --rm -i $image $cmd --version"));
                # Since SLES 16.0 (and SLEM 6.2), both docker & podman no longer automount credentials by default
                my $mount = (is_sle("16.0+") || is_sle_micro("6.2+")) ? "-v /etc/zypp/credentials.d/SCCcredentials:/etc/zypp/credentials.d/SCCcredentials:ro,z" : "";
                validate_script_output_retry("$runtime run --rm $mount $image $cmd lp", sub { m/.*All available products.*/ }, retry => 5, delay => 60, timeout => 300);
                validate_script_output_retry("$runtime run --rm $mount $image $cmd lm", sub { m/.*All available modules.*/ }, retry => 5, delay => 60, timeout => 300);
            }
        } else {
            record_info "non-SLE host", "This host ($host_id) does not support zypper service";
        }
    } else {
        $version =~ s/^Jump://i;
        validate_script_output qq{$runtime container run --entrypoint '/bin/bash' --rm $image -c 'cat /etc/os-release'}, sub { /PRETTY_NAME="openSUSE (Leap )?${version}.*"/ };
    }

    # Zypper is supported only on openSUSE or on SLE based image on SLE host
    if (($host_id =~ 'sles' && $image_id =~ 'sles' && !is_unreleased_sle) || $image_id =~ 'opensuse') {
        # If we are in not-released SLE host, we can't use zypper commands inside containers
        # that are not the same version as the host, so we skip this test.
        test_zypper_on_container($runtime, $image);
        build_and_run_image(base => $image, runtime => $runtime);
    }
}

sub test_zypper_on_container {
    my ($runtime, $image) = @_;
    record_info('zypper tests', 'Basic zypper commands in the container.');

    die 'Argument $image not provided!' unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

    validate_script_output_retry("$runtime run --rm -i --entrypoint '' $image zypper lr -s", sub { m/.*Alias.*Name.*Enabled.*GPG.*Refresh.*Service/ }, timeout => 180);
    assert_script_run("$runtime run -t -d --name 'refreshed' --entrypoint '' $image bash", timeout => 300);
    script_retry("$runtime exec refreshed zypper -nv --gpg-auto-import-keys ref", timeout => 600, retry => 3, delay => 120);
    assert_script_run("$runtime commit refreshed refreshed-image", timeout => 120);
    assert_script_run("$runtime rm -f refreshed");
    script_retry("$runtime run -i --rm --entrypoint '' refreshed-image zypper -nv ref", timeout => 300, retry => 3, delay => 60);
}

1;
