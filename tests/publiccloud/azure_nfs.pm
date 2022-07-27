# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test Azure NFS file shares
# - Create Azure VM and Azure storage account with NFS
# - mount the NFS share
# - perform basic file checks there (see check_nfs_share)
# This test uses the data/publiccloud/terraform/azure_nfstest.tf terraform profile
# to create a VM and a storage account in its own resource group. All resources are disposed after execution
# Maintainer: qa-c team <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use publiccloud::ssh_interactive "select_host_console";

# Mount directory for the NFS test
my $az_nfs_dir = "/mount/nfsdata";

sub check_nfs_share {
    my $share = shift;

    ##  NFS share test: Download some data and check permissions
    # * Download a file, and set the permission to read-only by owner
    # * Check if the permissiosn are correctly set
    # * Check if the default user (azureuser) can not read the file
    # * Check if hard links are working
    # * Check if soft links are working
    assert_script_run("cd $share");
    assert_script_run("curl -v -o Big_Buck_Bunny_8_seconds_bird_clip.ogv " . data_url('Big_Buck_Bunny_8_seconds_bird_clip.ogv'));
    assert_script_run("sync");
    assert_script_run("chmod 0400 Big_Buck_Bunny_8_seconds_bird_clip.ogv");
    assert_script_run("chown root:root Big_Buck_Bunny_8_seconds_bird_clip.ogv");
    validate_script_output('stat -c "%a" Big_Buck_Bunny_8_seconds_bird_clip.ogv', sub { m/400/ });
    assert_script_run("! sudo -u azureuser cat Big_Buck_Bunny_8_seconds_bird_clip.ogv >/dev/null");
    # Check file integrity via md5sums
    assert_script_run("md5sum Big_Buck_Bunny_8_seconds_bird_clip.ogv > Big_Buck_Bunny_8_seconds_bird_clip.ogv.md5");
    assert_script_run("mv Big_Buck_Bunny_8_seconds_bird_clip.ogv Big_Buck_Bunny_8_seconds_bird_clip.ogv.orig");
    # Check hard link
    my $inode = script_output('stat -c "%i" Big_Buck_Bunny_8_seconds_bird_clip.ogv.orig');    # save inode for later comparison
    validate_script_output('stat -c "%h" Big_Buck_Bunny_8_seconds_bird_clip.ogv.orig', sub { m/1/ });    # number of hard links must be 1
    assert_script_run("ln Big_Buck_Bunny_8_seconds_bird_clip.ogv.orig Big_Buck_Bunny_8_seconds_bird_clip.ogv");
    validate_script_output('stat -c "%h" Big_Buck_Bunny_8_seconds_bird_clip.ogv.orig', sub { m/2/ });    # number of hard links must now be 2
    validate_script_output('stat -c "%h" Big_Buck_Bunny_8_seconds_bird_clip.ogv', sub { m/2/ });
    validate_script_output('stat -c "%i" Big_Buck_Bunny_8_seconds_bird_clip.ogv', sub { m/$inode/ });    # compare inode of link
    assert_script_run("md5sum -c Big_Buck_Bunny_8_seconds_bird_clip.ogv.md5");
    assert_script_run("rm Big_Buck_Bunny_8_seconds_bird_clip.ogv");
    assert_script_run("! stat Big_Buck_Bunny_8_seconds_bird_clip.ogv");
    # Check soft link
    assert_script_run("ln -s Big_Buck_Bunny_8_seconds_bird_clip.ogv.orig Big_Buck_Bunny_8_seconds_bird_clip.ogv");
    assert_script_run("md5sum -c Big_Buck_Bunny_8_seconds_bird_clip.ogv.md5");
    assert_script_run("rm Big_Buck_Bunny_8_seconds_bird_clip.ogv.orig");
    assert_script_run("stat Big_Buck_Bunny_8_seconds_bird_clip.ogv");
    assert_script_run("! md5sum -c Big_Buck_Bunny_8_seconds_bird_clip.ogv.md5");    # must fail, because the soft-link is broken now
    assert_script_run("rm Big_Buck_Bunny_8_seconds_bird_clip.ogv");
}

sub run {
    my ($self, $args) = @_;

    my $instance = $args->{my_instance};
    my $resource_id = $instance->resource_id;
    record_info("resource_id", $resource_id);

    # Create mount point and canary to check if remote nfs is mounted
    assert_script_run("mkdir -p $az_nfs_dir");
    assert_script_run("echo 'This is the local directory' > $az_nfs_dir/local");
    # This is the location for the NFS file share created in the azure_nfstest.tf terraform profile
    # See https://docs.microsoft.com/en-us/azure/storage/files/storage-files-how-to-mount-nfs-shares
    my $share = "storage${resource_id}.file.core.windows.net:/storage${resource_id}/nfsdata";
    script_retry("mount -t nfs \"$share\" $az_nfs_dir -o vers=4,minorversion=1,sec=sys", retry => 3, delay => 120);
    assert_script_run("! stat $az_nfs_dir/local");    # Check for local canary
    assert_script_run("echo 'This is the remote NFS directory' > $az_nfs_dir/remote");

    check_nfs_share($az_nfs_dir);
}

sub cleanup() {
    script_run("cd");
    script_run("umount $az_nfs_dir");
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

1;
