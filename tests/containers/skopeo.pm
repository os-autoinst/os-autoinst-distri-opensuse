# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: skopeo
# Summary: Test basic skopeo commands.
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';    # used in select_serial_terminal
use utils 'zypper_call';    # used in zypper_call
use version_utils qw(is_transactional is_vmware);
use transactional;
use containers::common qw(install_packages);

sub run {
    my ($self, $args) = @_;

    # Required packages
    my @packages = qw(skopeo jq);

    select_serial_terminal() unless is_vmware;    # Select most suitable text console

    # Set a variable for my remote image
    my $remote_image = 'registry.suse.com/bci/bci-busybox:latest';
    # Set a variable for my working directory
    my $workdir = '/tmp/test';

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

    # Add cleanup routine.
    record_info('Cleanup', 'Delete copied image directories');
    assert_script_run("rm -rf $workdir/dir1/ dir2/", fail_message => 'Failed to remove temporary files.');

}

1;

