# Copyright © 2020 SUSE LLC
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

# Summary: Validate installer self update feature downloads updates and applies
#          them to the system
# Maintainer: QA SLE YaST <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;
    select_console('install-shell');
    my $self_update_repo = get_required_var('INSTALLER_SELF_UPDATE');
    assert_script_run("grep /var/log/YaST2/y2log -e '$self_update_repo'",
        fail_message => 'Expected to have log entries that self update repo was contacted');
    assert_script_run('test -n "$(ls -A /download)"',
        fail_message => '/download directory is empty, expected to contain downloaded updates');
    assert_script_run('mount | grep -P "/download/yast_\d+"',
        fail_message => 'updates are not mounted, expected /download/yast_* to be mounted as /mount/yast_*');
    select_console('installation');
}

1;
