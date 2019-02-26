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
use warnings;
use testapi;
use utils qw(zypper_call pkcon_quit);
use version_utils 'is_sle';


sub run {
    my $self = shift;
    return unless is_sle('15+');
    # try to detect bsc#1054782 only on the backend which can handle
    # 'ctrl-alt-f2' directly
    if (check_var('BACKEND', 'qemu')) {
        send_key('ctrl-alt-f2');
        assert_screen(["tty2-selected", 'text-login', 'text-logged-in-root', 'generic-desktop']);
        if (match_has_tag 'generic-desktop') {
            record_soft_failure 'bsc#1054782';
        }
    }
    select_console('root-console');
    # Stop packagekit
    pkcon_quit;
}

1;
