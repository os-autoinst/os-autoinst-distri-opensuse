# SUSE's openQA tests
#
# Copyright 2021-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: buildah
# Summary: building OCI-compatible sle base images with buildah.
# - install buildah
# - create container from existing image
# - install package in the container
# - copy script to container and run it
# - metadata configuration
# - commit image
# - cleanup system (images, containers)
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(get_os_release is_sle);
use containers::common;

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    my ($running_version, $sp, $host_distri) = get_os_release;

    my $runtime = $args->{runtime};
    my $image = "registry.opensuse.org/opensuse/tumbleweed:latest";

    record_info('Test', "Install buildah along with $runtime");
    install_buildah_when_needed($host_distri);
    install_podman_when_needed($host_distri) if ($runtime eq 'podman');
    if ($runtime eq 'docker') {
        install_docker_when_needed($host_distri);
        zypper_call('install skopeo');

        # temporarily necessary due to https://bugzilla.suse.com/show_bug.cgi?id=1220568
        zypper_call('install cni-plugins') if (is_sle("15-SP3+"));
    }
    record_info('Version', script_output('buildah --version'));

    record_info('Test', "Pull image $image");
    assert_script_run("buildah pull $image", timeout => 300);
    validate_script_output('buildah images', sub { /registry.opensuse.org\/opensuse\/tumbleweed/ });

    record_info('Test', "Create container from $image");
    my $container = script_output("buildah from $image");
    validate_script_output('buildah containers', sub { /tumbleweed-working-container/ });
    validate_script_output("buildah run $container -- cat /etc/os-release", sub { /openSUSE Tumbleweed/ });

    # When trying to install packages inside the container in Docker, there's a
    # network failure
    if ($runtime eq 'podman') {
        record_info('Test', "Install random package in the container");
        assert_script_run("buildah run $container -- zypper in -y python3", timeout => 300);
        assert_script_run("buildah run $container -- python3 --version");
    }

    record_info('Test', "Add environment variable to the container");
    assert_script_run("buildah config --env foo=bar $container");
    validate_script_output("buildah run $container -- bash -c 'echo \$foo'", sub { /bar/ });

    record_info('Test', "Copy executable script to container and run it");
    assert_script_run("curl -f -v " . data_url("containers/script.sh") . " -o /tmp/script.sh");
    assert_script_run("chmod +x /tmp/script.sh");
    assert_script_run("buildah copy $container /tmp/script.sh /usr/bin");
    assert_script_run("buildah config --cmd /usr/bin/script.sh $container");
    validate_script_output("buildah run $container /usr/bin/script.sh", sub { /Test shall pass/ });

    record_info('Test', "Inject configuration metadata into the container");
    assert_script_run("buildah config --created-by 'openQA' $container");
    assert_script_run("buildah config --author 'someone at suse.com' --label name=buildah_openqa_test $container");
    validate_script_output("buildah inspect --format '{{.ImageCreatedBy}}' $container", sub { /openQA/ });
    validate_script_output("buildah inspect --format '{{.OCIv1.Author}}' $container", sub { /someone at suse.com/ });
    validate_script_output("buildah inspect --format '{{.OCIv1.Config.Labels.name}}' $container", sub { /buildah_openqa_test/ });

    record_info('Test', "Commit image and use it with podman or docker");
    assert_script_run("buildah commit $container newimage", timeout => 300);
    validate_script_output("buildah images", sub { /newimage/ });
    # There's need to copy the new image to Docker's storage
    assert_script_run('skopeo copy containers-storage:localhost/newimage:latest docker-daemon:localhost/newimage:latest')
      if ($runtime eq 'docker');
    validate_script_output("$runtime run --rm localhost/newimage", sub { /Test shall pass/ });

    record_info('Test', "Create image with new tag");
    assert_script_run("buildah tag newimage newimage:sometag");
    assert_script_run("buildah inspect newimage:sometag");

    record_info('Test', "Cleanup");
    assert_script_run("buildah rm $container");
    assert_script_run("buildah rmi newimage");
}

1;
