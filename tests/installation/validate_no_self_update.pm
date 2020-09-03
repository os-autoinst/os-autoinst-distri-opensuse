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

# Summary: Validate installer self update is not attempted when explicitly disabled
# Maintainer: QA SLE YaST <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;
    select_console('install-shell');
    assert_script_run('test -z "$(ls -A /download | grep yast_)"',
        fail_message => '/download directory contains updates, expected not to contain any yast_* files');
    assert_script_run('! grep /var/log/YaST2/y2log -e "Trying installer update"',
        fail_message => 'YaST logs contain entry that self update was attempted, but is explicitly disabled');
    select_console('installation');
}

1;
