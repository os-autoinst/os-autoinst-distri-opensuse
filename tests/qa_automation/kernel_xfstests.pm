# Copyright (C) 2017 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary:  xfstests testsuite
# Use the latest xfstests testsuite from upstream to make file system test
# Maintainer: Yong Sun <yosun@suse.com>

use base "qa_run";
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;
    $self->system_login();
    $self->prepare_repos();
    # create test partition
    assert_script_run("parted -l -m 2>&1");
    my $cmd           = "parted -l -m 2>&1| awk -F \':\' \'{if(\$5 == \"xfs\") print \$1}\'";
    my $partition_num = $self->qa_script_output($cmd, 10);
    my $partition     = "/dev/vda" . $partition_num;
    assert_script_run("fdisk -l " . $partition);
    # add extra repo, because original qa-head repo don't contain some packages required by xfstests
    assert_script_run("cd /root/");
    assert_script_run("zypper ar http://download.suse.de/ibs/home:/yosun:/branches:/QA:/Head:/Devel/SLE-12-SP2/ extra-repo");
    assert_script_run("zypper ref");
    assert_script_run("zypper lr -U");
    # prepare/clone/make/install xfstests
    assert_script_run(
"zypper -n in git e2fsprogs automake gcc libuuid1 quota attr make xfsprogs libgdbm4 gawk dbench uuid-runtime acl bc dump indent libtool lvm2 psmisc sed xfsdump libacl-devel libattr-devel libaio-devel libuuid-devel openssl-devel xfsprogs-devel",
        60 * 10
    );
    assert_script_run("git clone git://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git", 60 * 10);
    assert_script_run("cd xfstests-dev");
    assert_script_run("make",         60 * 10);
    assert_script_run("make install", 60 * 5);
    # prepare and run xfstests (./check is the trigger script)
    #TODO# also add scratch partition to make multi-partition test
    assert_script_run("useradd fsgqa");
    assert_script_run("mkdir /mnt/test /mnt/scratch");
    assert_script_run("mount " . $partition . " /mnt/test");
    assert_script_run("mount");
    assert_script_run("export TEST_DIR=/mnt/test");
    assert_script_run("export TEST_DEV=" . $partition);
    script_run("./check", 60 * 60);
    # Upload all log tarballs in ./results/
    my $tarball = "/tmp/qaset-xfstests-results.tar.bz2";
    assert_script_run("tar jcvf " . $tarball . " ./results/");
    upload_logs($tarball);
}

1;
