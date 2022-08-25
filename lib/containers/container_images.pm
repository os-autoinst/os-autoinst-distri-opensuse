# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
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

our @EXPORT = qw(build_with_zypper_docker build_with_sle2docker
  test_opensuse_based_image exec_on_container ensure_container_rpm_updates build_and_run_image
  test_zypper_on_container test_3rd_party_image upload_3rd_party_images_logs test_systemd_install);

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

    # At least on publiccloud, this image pull can take long and occasinally fails due to network issues
    $builder->build($dir . "/BuildTest", "myapp", (timeout => is_x86_64 ? 600 : 1200));
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
    script_retry("$runtime ps -a | grep myapp", delay => 5, retry => 3);    # ensure container is running
    assert_script_run("$runtime logs myapp");    # show logs for easier problem investigation

    # Test that the exported port is reachable
    script_retry('curl http://localhost:8888/ | grep "The test shall pass"', delay => 5, retry => 6);

    # Cleanup
    assert_script_run("$runtime stop myapp");
    assert_script_run("$runtime rm myapp");
}

# Build a sle container image using zypper_docker
sub build_with_zypper_docker {
    my %args = @_;
    my $image = $args{image};
    my $runtime = $args{runtime};
    my $derived_image = "zypper_docker_derived";

    my $distri = $args{distri} //= get_required_var("DISTRI");
    my $version = $args{version} //= get_required_var("VERSION");

    die 'Argument $image not provided!' unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

    my ($host_version, $host_sp, $host_id) = get_os_release();
    my ($image_version, $image_sp, $image_id) = get_os_release("$runtime run $image");

    # The zypper-docker works only on openSUSE or on SLE based image on SLE host
    unless (($host_id =~ 'sles' && $image_id =~ 'sles') || $image_id =~ 'opensuse') {
        record_info 'Warning!', 'The zypper-docker only works for openSUSE based images and SLE based images on SLE host.';
        return;
    }

    if ($distri eq 'sle') {
        my $pretty_version = $version =~ s/-SP/ SP/r;
        my $betaversion = get_var('BETA') ? '\s\([^)]+\)' : '';
        validate_script_output("$runtime run --entrypoint '/bin/bash' --rm $image -c 'cat /etc/os-release'",
            sub { /"SUSE Linux Enterprise Server ${pretty_version}${betaversion}"/ });
    } else {
        $version =~ s/^Jump://i;
        validate_script_output qq{$runtime container run --entrypoint '/bin/bash' --rm $image -c 'cat /etc/os-release'}, sub { /PRETTY_NAME="openSUSE (Leap )?${version}.*"/ };
    }

    zypper_call("in zypper-docker") if (script_run("which zypper-docker") != 0);
    script_retry("zypper-docker list-updates $image", timeout => 300, retry => 3, delay => 60);
    script_retry("zypper-docker up $image $derived_image", timeout => 300, retry => 3, delay => 60);

    # If zypper-docker list-updates lists no updates then derived image was successfully updated
    script_retry("zypper-docker list-updates $derived_image | grep 'No updates found'", timeout => 300, retry => 3, delay => 60);

    my $local_images_list = script_output("$runtime image ls");
    die("$runtime $derived_image not found") unless ($local_images_list =~ $derived_image);

    record_info("Testing derived", "Derived image: $derived_image");
    test_opensuse_based_image(image => $derived_image, runtime => $runtime, version => $version);

    assert_script_run("docker rmi -f $derived_image");
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
    my ($image_version, $image_sp, $image_id) = get_os_release("$runtime run --entrypoint '' $image");

    record_info "Host", "Host has '$host_version', '$host_sp', '$host_id' in /etc/os-release";
    record_info "Image", "Image has '$image_version', '$image_sp', '$image_id' in /etc/os-release";

    $version = 'Tumbleweed' if ($version =~ /^Staging:/);

    if ($image_id =~ 'sles') {
        if ($host_id =~ 'sles') {
            my $pretty_version = $version =~ s/-SP/ SP/r;
            my $betaversion = $beta ? '\s\([^)]+\)' : '';
            record_info "Validating", "Validating That $image has $pretty_version on /etc/os-release";
            # zypper-docker changes the layout of the image (Note: We may have images without 'grep')
            validate_script_output("$runtime run --entrypoint /bin/bash $image -c 'cat /etc/os-release' | grep PRETTY_NAME | cut -d= -f2",
                sub { /"SUSE Linux Enterprise Server ${pretty_version}${betaversion}"/ });

            # SUSEConnect zypper service is supported only on SLE based image on SLE host
            unless (is_unreleased_sle) {
                # we set --entrypoint specifically to the zypper plugin to avoid bsc#1192941
                my $plugin = '/usr/lib/zypp/plugins/services/container-suseconnect-zypp';
                validate_script_output("$runtime run --entrypoint $plugin -i $image -v", sub { m/container-suseconnect version .*/ }, timeout => 180);
                validate_script_output_retry("$runtime run --entrypoint $plugin -i $image lp", sub { m/.*All available products.*/ }, retry => 5, delay => 60, timeout => 300);
                validate_script_output_retry("$runtime run --entrypoint $plugin -i $image lm", sub { m/.*All available modules.*/ }, retry => 5, delay => 60, timeout => 300);
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
        if (is_sle && $runtime->runtime eq 'docker') {
            build_with_zypper_docker(image => $image, runtime => $runtime, version => $version);
        }
    }
}

sub test_zypper_on_container {
    my ($runtime, $image) = @_;
    record_info('zypper tests', 'Basic zypper commands in the container.');

    die 'Argument $image not provided!' unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

    # Check for bsc#1192941, which affects the docker runtime only - this is just check not softfailure as this won't be fixed.
    # bsc#1192941 states that the entrypoint of a derived image is set in a way, that program arguments are not passed anymore
    # we run 'zypper ls' on a container, and if we detect the zypper usage message, we know that the 'ls' parameter was ignored
    if ($runtime->runtime eq 'docker') {
        my $zypper_output = script_output_retry("docker run --rm -ti $image zypper ls", timeout => 270, delay => 60, retry => 3);
        record_info('bsc#1192941', 'bsc#1192941 - zypper-docker entrypoint confuses program arguments') if ($zypper_output =~ /Usage:/);
    }
    validate_script_output_retry("$runtime run -i --entrypoint '' $image zypper lr -s", sub { m/.*Alias.*Name.*Enabled.*GPG.*Refresh.*Service/ }, timeout => 180);
    assert_script_run("$runtime run -t -d --name 'refreshed' --entrypoint '' $image bash", timeout => 300);
    script_retry("$runtime exec refreshed zypper -nv ref", timeout => 600, retry => 3, delay => 60);
    assert_script_run("$runtime commit refreshed refreshed-image", timeout => 120);
    assert_script_run("$runtime rm -f refreshed");
    script_retry("$runtime run -i --rm --entrypoint '' refreshed-image zypper -nv ref", timeout => 300, retry => 3, delay => 60);
}

sub exec_on_container {
    my ($image, $runtime, $command, $timeout) = @_;
    $timeout //= 120;
    $runtime->run_container($image, cmd => $command, daemon => 1, timeout => $timeout);
}

sub test_3rd_party_image {
    my ($runtime, $image) = @_;
    my $runtime_name = $runtime->runtime;
    record_info('IMAGE', "Testing $image with $runtime_name");
    test_container_image(image => $image, runtime => $runtime);
    script_run("echo 'OK: $runtime_name - $image:latest' >> /var/tmp/${runtime_name}-3rd_party_images_log.txt");
}

sub upload_3rd_party_images_logs {
    my $runtime = shift;
    # Rename for better visibility in Uploaded Logs
    if (script_run("mv /var/tmp/$runtime-3rd_party_images_log.txt /tmp/$runtime-3rd_party_images_log.txt") != 0) {
        record_info("No logs", "No logs found");
    } else {
        upload_logs("/tmp/$runtime-3rd_party_images_log.txt");
        script_run("rm /tmp/$runtime-3rd_party_images_log.txt");
    }
}

sub test_systemd_install {
    my %args = @_;
    my $image = $args{image};
    my $runtime = $args{runtime};

    die 'Argument $image not provided!' unless $image;
    die 'Argument $runtime not provided!' unless $runtime;

    my ($image_version, $image_sp, $image_id) = get_os_release("$runtime run --entrypoint '' $image");
    # TW and starting with SLE 15-SP4/Leap15.4 systemd's dependency with udev has been dropped
    if ($image_id eq 'opensuse-tumbleweed' ||
        ($image_id eq 'opensuse-leap' && check_version('>=15.4', "$image_version.$image_sp", qr/\d{2}\.\d/)) ||
        ($image_id eq 'sles' && check_version('>=15-SP4', "$image_version-SP$image_sp", qr/\d{2}-sp\d/))) {
        assert_script_run("$runtime run $image /bin/bash -c 'zypper al udev && zypper -n in systemd'", timeout => 300);
    }
}

1;
