# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package xfstests_install;
# Summary:  Package install and envirorment prepare related base class for xfstests_run
# Maintainer: Yong Sun <yosun@suse.com>

use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use utils;
use testapi qw(is_serial_terminal :DEFAULT);

sub system_login {
    my $self = shift;
    $self->wait_boot;
    $self->select_serial_terminal;
}

# Add and refresh repos
sub prepare_repo {
    my $self           = shift;
    my $qa_server_repo = get_var('QA_SERVER_REPO', '');
    my $qa_sdk_repo    = get_var('QA_SDK_REPO', '');
    pkcon_quit;
    if ($qa_server_repo) {
        # Remove all existing repos and add QA_SERVER_REPO
        script_run('for ((i = $(zypper lr| tail -n+5 |wc -l); i >= 1; i-- )); do zypper -n rr $i; done; unset i', 300);
        zypper_call("--no-gpg-check ar -f '$qa_server_repo' server-repo");
        # Add QA_SDK_REPO if need
        if ($qa_sdk_repo) {
            zypper_call("--no-gpg-check ar -f '$qa_sdk_repo' sle-sdk");
        }
    }
    my $qa_web_repo = get_var('QA_WEB_REPO', '');
    if ($qa_web_repo) {
        zypper_call("--no-gpg-check ar -f '$qa_web_repo' qa-web");
    }
    # sometimes updates.suse.com is busy, so we need to wait for possiblye retries
    zypper_call("--gpg-auto-import-keys ref");
}

# Install xfstests from upstream git repo
sub prepare_testpackage {
    my $self = shift;
    assert_script_run("cd /root/");
    assert_script_run("zypper ref", 60);
    assert_script_run(
"zypper -n in git e2fsprogs automake gcc libuuid1 quota attr make xfsprogs libgdbm4 gawk uuid-runtime acl bc dump indent libtool lvm2 psmisc sed xfsdump libacl-devel libattr-devel libaio-devel libuuid-devel openssl-devel xfsprogs-devel parted",
        60 * 10
    );
    assert_script_run("git clone git://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git", 60 * 10);
    assert_script_run("cd xfstests-dev");
    assert_script_run("make",         60 * 10);
    assert_script_run("make install", 60 * 5);
}

# Prepare envirorment and all parameters for running xfstests (e.g. test_partition format as /dev/vda2)
sub prepare_env {
    my $self = shift;
    my ($test_partition, $scratch_partition) = @_;
    print("xfstests_install: test partition is $test_partition, scratch partition is $scratch_partition \n");
    assert_script_run("useradd fsgqa");
    assert_script_run("mkdir /home/fsgqa");
    assert_script_run("groupadd fsgqa");
    assert_script_run("usermod -g fsgqa fsgqa");
    assert_script_run("mkdir /mnt/test /mnt/scratch");
    assert_script_run("mount " . $test_partition . " /mnt/test");
    assert_script_run("export TEST_DIR=/mnt/test");
    assert_script_run("export TEST_DEV=" . $test_partition, 10);
    assert_script_run("export SCRATCH_DIR=/mnt/scratch");
    assert_script_run("export SCRATCH_DEV=" . $scratch_partition, 10);
    assert_script_run("export SCRATCH_MNT=/mnt/scratch");

    #to get more useful logs
    assert_script_run("dmesg -n 7");
    systemctl 'stop cron';
}

1;
