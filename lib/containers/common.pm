# Copyright (C) 2015-2020 SUSE LLC
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

package containers::common;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use registration;
use utils qw(zypper_call systemctl);
use version_utils qw(is_sle is_caasp);

our @EXPORT = qw(install_docker_when_needed clean_docker_host);

sub install_docker_when_needed {
    if (is_caasp) {
        # Docker should be pre-installed in MicroOS
        die 'Docker is not pre-installed.' if zypper_call('se -x --provides -i docker');
    }
    else {
        if (script_run("which docker") != 0) {
            if (is_sle() && script_run("SUSEConnect --status-text | grep Containers") != 0) {
                add_suseconnect_product("sle-module-containers");
            }

            # docker package can be installed
            zypper_call('in docker', timeout => 900);
        }
    }

    # docker daemon can be started
    systemctl('enable docker') if systemctl('is-enabled docker', ignore_failure => 1);
    systemctl('start docker')  if systemctl('is-active docker',  ignore_failure => 1);
    systemctl('status docker');
    assert_script_run('docker info');
}

sub clean_docker_host {
    assert_script_run('docker stop $(docker ps -q)', 180) if script_output('docker ps -q | wc -l') != '0';
    assert_script_run('docker system prune -a -f',   180);
}

1;

