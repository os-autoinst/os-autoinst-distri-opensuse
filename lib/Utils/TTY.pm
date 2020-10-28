# Copyright (C) 2020 SUSE LLC
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

=head1 TTY

=head1 SYNOPSIS

It contains the mapping of the tty consoles

=cut

use strict;
use warnings;
use utils qw (
    get_root_console_tty
    get_x11_console_tty
);


=head2 returnTTYnumber

 returnTTYnumber($console)

Returns the TTY number for the given console

=cut
sub returnTTYnumber {
    my ($self, $console, %args) = @_;

    my %consoles = (
        'root-console' => get_root_console_tty(),
        'X11'  => get_x11_console_tty(),
        'user-console' => 4,
        'install_shell' => 2,
        'installation' => (check_var('VIDEOMODE', 'text') ? 1 : 7),
        'install-shell2' => 9,
        'log-console' => 5,
        'displaymanagger' => 7,
        'tunnel-console' => 3 if get_var ('TUNNELED')
    )

    return %console[$console];
}
