# Copyright © 2017 SUSE LLC
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

use base "xfstests_install";
use base "xfstests_device";
use base "xfstests_logs";
use strict;
use testapi;

sub run() {
    my $self = shift;
    $self->system_login();
    $self->prepare_repo();

    #Split /home into many partitions
    my ($test_partition, $scratch_partition, $test_fs_type) = $self->dev_create_partition();

    #Install xfstests test package
    $self->prepare_testpackage();

    #Prepare envirorment and all parameters before run test
    $self->prepare_env($test_partition, $scratch_partition);

    #Modify obsoleted "hostname -s" to "hostname" in ./common/rc and ./common/config
    script_run("sed -i \"s/hostname -s/hostname/\" ./common/rc");
    script_run("sed -i \"s/hostname -s/hostname/\" ./common/config");

    script_run("./check", 60 * 60 * 6);

    # Upload all log tarballs in ./results/
    $self->log_upload();
}

1;
