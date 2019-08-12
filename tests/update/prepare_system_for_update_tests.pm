# Copyright (C) 2017-2018 SUSE LLC
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

# Summary: Prepare system for actual desktop specific updates
# - Disable delta rpms if system is not sle
# - Unmask packagekit service
# - Run "pkcon refresh"
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    ensure_serialdev_permissions;
    # default is true, for legacy reasons we were running this on openSUSE only
    assert_script_run "echo \"download.use_deltarpm = false\" >> /etc/zypp/zypp.conf" if !is_sle;
    systemctl 'unmask packagekit';

    assert_script_run "pkcon refresh", 300;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    $self->upload_packagekit_logs;
}

1;
