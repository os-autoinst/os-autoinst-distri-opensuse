# Copyright (C) 2019 SUSE LLC
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

# Summary: Base class for the ssh_interactive initiation phase
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

package publiccloud::ssh_interactive_init;
use base "consoletest";

use strict;
use warnings;
use testapi;

sub post_fail_hook {
    select_console 'tunnel-console', await_console => 0;
    send_key "ctrl-c";
    send_key "ret";
    assert_script_run('cd /root/terraform');
    script_run('terraform destroy -no-color -auto-approve', 240);
}

sub test_flags {
    return {
        fatal                    => 1,
        milestone                => 0,
        publiccloud_multi_module => 1
    };
}

1;
