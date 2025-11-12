# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: skopeo
# Summary: Test basic skopeo commands.
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(script_retry zypper_call);
use version_utils qw(is_transactional is_vmware is_opensuse);
use transactional;
use containers::common qw(install_packages);

# Set a variable for test working directory
my $workdir = '/tmp/test';

sub run {
    # Required packages
    my @packages = qw(skopeo jq);

    select_serial_terminal() unless is_vmware;    # Select most suitable text console

    # Set a variable for my remote image
    my $remote_image = is_opensuse ? "registry.opensuse.org/opensuse/bci/bci-busybox:latest" : "registry.suse.com/bci/bci-busybox:latest";
    # Set a variable for my local image
    my $local_image = 'localhost:5050/bci-busybox:latest';

    # install_packages accounts for SLE-Micro environment with transactional-update
    record_info('Installing packages', 'Install required packages');
    install_packages(@packages);

    record_info('skopeo version', script_output("skopeo --version"));

    # Create test directory
    script_run("mkdir $workdir");

    ######### Inspect a docker repository
    # assert_script_run --> runs the command and die unless it returns zero, indicating successful completion of $cmd
    record_info('Inspect', 'Inspect a docker repository');
    assert_script_run("skopeo inspect docker://$remote_image",
        fail_message => 'Failed to inspect remote image.');

    ######### Pull the image into a directory
    record_info('Pull Image', 'Pull image into a directory');
    validate_script_output("skopeo copy docker://$remote_image dir:$workdir",
        sub { m/Writing manifest to image destination/ },
        fail_message => 'Failed to copy image.');

    # Unpacked contents must include a manifest and version
    record_info('Verify files', 'Unpacked contents must include manifest.json and version files.');
    assert_script_run("stat $workdir/manifest.json", fail_message => "manifest.json not present");
    assert_script_run("stat $workdir/version", fail_message => "version not present");
    # stat command prints details about files and file systems. It will fail if the file is not present.

    ######### Run inspect locally
    record_info('Inspect', 'Run inspect locally');
    assert_script_run("skopeo inspect dir:$workdir",
        fail_message => 'Failed to inspect local image.');

    # skopeo inspect --raw dir:/tmp/test   <---- inspects raw manifest or configuration
    assert_script_run("skopeo inspect --raw dir:$workdir",
        fail_message => 'Failed to inspect local image.');

    # use jq to extract the value of .config.digest field from raw JSON data
    assert_script_run("skopeo inspect --raw dir:$workdir | jq '.config.digest'",
        fail_message => 'Failed to inspect local image.');

    ######### Copy tests
    # Copy from remote to dir1, to dir2;
    # Compare dir1 and dir2, expect no changes.
    record_info('Copy images', 'Copy images from remote to dir1, to dir2');
    my $dir1 = "$workdir/dir1";
    my $dir2 = "$workdir/dir2";

    # Copy from remote to dir1
    # Combine mkdir and skopeo in a single line to account for missing directory:
    assert_script_run("mkdir -p $dir1 && skopeo copy docker://$remote_image dir:$dir1",
        fail_message => 'Failed to copy remote image to directory');

    # Copy from dir1 to dir2
    assert_script_run("mkdir -p $dir2 && skopeo copy dir:$dir1 dir:$dir2",
        fail_message => 'Failed to copy local image from one directory to another.');

    # Both extracted copies must be identical.
    # diff flags: -u is human readable format, -r compare subdirectories, N treats all files as text.
    # assert_script_run will return 0 if there is no difference and 1 if there are differences.
    record_info('Compare images', 'Both extracted copies must be identical.');
    assert_script_run("diff -urN $dir1 $dir2", fail_message => 'Copied images are not identical.');

    ######### Spin-up an instance of the latest Registry
    my $registry_image = is_opensuse ? "registry.opensuse.org/opensuse/registry:latest" : "registry.suse.com/suse/registry:latest";
    assert_script_run("podman run --rm -d -p 5050:5000 --name skopeo-registry $registry_image",
        fail_message => "Failed to start local registry container");

    ######### Wait until the registry is up
    script_retry("curl http://localhost:5050/v2", delay => 2, fail_message => "Local registry not reachable");

    ######### Pull the image into a our local repository
    # skipping tls verification as by default most local registries don't have certificates
    record_info('Copy Image', 'Copy image from remote repository into the local repository.');
    validate_script_output("skopeo copy --remove-signatures --dest-tls-verify=0 docker://$remote_image docker://$local_image",
        sub { m/Writing manifest to image destination/ },
        fail_message => 'Failed to copy image to local repository.');

    ######### Inspect the local image repository
    # skipping tls verification as by default most local registries don't have certificates
    record_info('Inspect Image', 'Inspect an image from the local repository.');
    assert_script_run("skopeo inspect --tls-verify=0 docker://$local_image",
        fail_message => 'Failed to inspect local image.');

    ######### Compare remote image to local image
    # using JQ to omit any repository-specific fields which are expected to be different
    record_info('Verify Remote Image', 'Inspect remote image and save results.');
    assert_script_run("skopeo inspect --tls-verify=0 docker://$remote_image | jq .Layers[] >> $workdir/inspect_remote.json",
        fail_message => 'Failed to inspect remote image.');

    record_info('Verify Local Image', 'Inspect local image and save results.');
    assert_script_run("skopeo inspect --tls-verify=0 docker://$local_image | jq .Layers[] >> $workdir/inspect_local.json",
        fail_message => 'Failed to inspect local image.');

    record_info('Compare local and remote images', 'Compare local and remote images.');
    assert_script_run("diff $workdir/inspect_remote.json $workdir/inspect_local.json",
        fail_message => 'Images are not identical!');
}

sub cleanup {
    record_info('Cleanup', 'Delete copied image directories');
    script_run "rm -rf $workdir";

    record_info('Cleanup Registry', 'Remove local image Registry');
    script_run "podman stop skopeo-registry";
    script_run "podman rm -vf skopeo-registry";
}

sub post_run_hook {
    cleanup;
}

sub post_fail_hook {
    cleanup;
}

1;

