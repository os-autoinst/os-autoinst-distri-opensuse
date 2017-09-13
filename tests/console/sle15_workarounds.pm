# Copyright (C) 2014-2017 SUSE LLC
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
# Summary: performing extra actions specific to sle 15 which are not available normally
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base qw(consoletest distribution);
use strict;
use testapi;
use utils qw(zypper_call sle_version_at_least pkcon_quit);


sub run {
    my $self = shift;
    return unless sle_version_at_least('15');
    send_key('ctrl-alt-f2');
    assert_screen(["tty2-selected", 'text-login', 'text-logged-in-root', 'generic-desktop']);
    if (match_has_tag 'generic-desktop') {
        record_soft_failure 'bsc#1054782';
    }
    select_console('root-console');
    # Stop packagekit
    pkcon_quit;
    if (script_run('test -f /etc/products.d/baseproduct')) {
        record_soft_failure('bsc#1049164');
        assert_script_run('ln -s /etc/products.d/SLES.prod /etc/products.d/baseproduct');
    }
}

1;
# vim: set sw=4 et:
