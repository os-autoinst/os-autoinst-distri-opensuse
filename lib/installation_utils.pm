# Copyright (C) 2018 SUSE LLC
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

package installation_utils;

use base Exporter;
use Exporter;
use strict;
use testapi qw(check_var get_var);

our @EXPORT = qw (
  is_remote_installation
);

sub is_remote_installation {
    my ($self) = @_;

    return (check_var('BACKEND', 'ipmi') && !check_var('AUTOYAST', '1') || get_var('SES5_DEPLOY'));
}

1;
