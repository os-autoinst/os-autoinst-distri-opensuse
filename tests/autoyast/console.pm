# Copyright (C) 2015-2019 SUSE LLC
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

# Summary: Make sure we are logged in
# - Wait for boot if BACKEND is ipmi
# - Set root-console
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;

sub run {
    my ($self) = @_;
    $self->wait_boot if check_var('BACKEND', 'ipmi');
    select_console 'root-console';
}

1;

