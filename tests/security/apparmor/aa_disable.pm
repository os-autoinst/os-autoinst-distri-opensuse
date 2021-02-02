# Copyright (C) 2021 SUSE LLC
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
# Summary: Test AppArmor aa-disable - disable an AppArmor security profile.
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#81730, tc#1767574

use strict;
use warnings;
use base "apparmortest";
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    $self->test_profile_content_is_special("aa-disable", "Disabling.*");
}

1;
