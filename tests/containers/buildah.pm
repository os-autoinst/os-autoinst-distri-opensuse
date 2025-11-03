# SUSE's openQA tests
#
# Copyright 2021-2025 SUSE LLC
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
use serial_terminal qw(select_serial_terminal select_user_serial_terminal);
use utils;
use version_utils qw(is_sle is_public_cloud);
use containers::common;
use Utils::Backends qw(is_svirt);

sub run_tests {
    my $image = get_var("CONTAINER_IMAGE_TO_TEST", "registry.opensuse.org/opensuse/tumbleweed:latest");
    record_info('buildah info', script_output("buildah info"));
    record_info('Test', "Pull image $image");
    assert_script_run("buildah pull $image", timeout => 300);
    validate_script_output('buildah images', sub { /\/tumbleweed/ });

    record_info('Test', "Create container from $image");
    my $container = script_output("buildah from $image");
    validate_script_output('buildah containers', sub { /tumbleweed-working-container/ });
    validate_script_output("buildah run $container -- cat /etc/os-release", sub { /openSUSE Tumbleweed/ });

    record_info('Test', "Install arbitrary package in the container");
    assert_script_run("buildah run $container -- zypper in -y perl", timeout => 600);
    assert_script_run(qq{buildah run $container -- perl -e 'print("Hello World\\n");'});

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
    validate_script_output("podman run --rm localhost/newimage", sub { /Test shall pass/ });

    record_info('Test', "Create image with new tag");
    assert_script_run("buildah tag newimage newimage:sometag");
    assert_script_run("buildah inspect newimage:sometag");

    record_info('Test', "Cleanup");
    assert_script_run("buildah rm $container");
    assert_script_run("buildah rmi -f newimage $image");
    assert_script_run("buildah rmi -af");
    assert_script_run("rm -f /tmp/script.sh");

    if (!get_var("OCI_RUNTIME")) {
        my $runtime = script_output("buildah info --format '{{ .host.OCIRuntime }}'");
        die "Unexpected OCI runtime: $runtime" if ($runtime ne "runc");
    }
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    install_buildah_when_needed();
    install_podman_when_needed();
    record_info('Version', script_output('buildah --version'));
    record_info('buildah info', script_output("buildah info"));

    # Run tests as user
    if (!is_public_cloud && !is_svirt) {
        select_user_serial_terminal;
        record_info('Test as user');
        run_tests;
        select_serial_terminal;
    }

    # Run tests as root
    record_info('Test as root');
    run_tests;
}

1;
