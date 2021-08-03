# Copyright © 2021 SUSE LLC
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
#
# Summary: Live migration test for destination host
#
# - Wait for guest migration initiated from source host after installation.
#
# Maintainer: Tony Yuan <tyuan@suse.com>

package live_migration_dst;
use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use Utils::Systemd 'systemctl';
use lockapi;
use mmapi;
use virt_autotest::utils 'collect_virt_system_logs';
require 'sle/tests/virtualization/livemigration/live_migration_src.pm';

my $images_path = "/var/lib/libvirt/images";

barrier_create('let_dst_upload_logs', 2);

sub run {
    select_console 'root-ssh';
    # live_migration_src::cleanup_for_rerun() if (check_var('HOST_INSTALL', '0'));
    if (check_var('HOST_INSTALL', 0)) {
        live_migration_src::cleanup_for_rerun();
    } else {
        upload_logs('/var/log/zypp/history');
    }

    #Wait for the guests to be created and ready for migration
    mutex_create 'dst_ready';
    #wait to collect logs
    barrier_wait {name => 'let_dst_upload_logs', check_dead_job => 1};
    #Logs won't be collected if test is passed on src host
    if (script_run("[[ -f $images_path/test_state/test_done ]]") == 0) {
        assert_script_run("dmesg --level=emerg,crit,alert,err > /tmp/dmesg_err.txt");
        upload_logs('/tmp/dmesg_err.txt') if (script_run("[[ -s  /tmp/dmesg_err.txt ]]") == 0);
        assert_script_run("rm $images_path/test_state/test_done");
    } else {
        collect_virt_system_logs;
    }
    #wait until all children finish
    wait_for_children;
}

1;
