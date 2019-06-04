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

package consoletest;
use base "opensusebasetest";

use strict;
use warnings;

use testapi;
use known_bugs;

=head1 consoletest

C<consoletest> - Base class for all console tests

=cut

=head2 post_run_hook

Method executed when run() finishes.

=cut
sub post_run_hook {
    my ($self) = @_;

    # start next test in home directory
    type_string "cd\n";

    # clear screen to make screen content ready for next test
    $self->clear_and_verify_console;
}

=head2 post_fail_hook

Method executed when run() finishes and the module has result => 'fail'

=cut
sub post_fail_hook {
    my ($self) = shift;
    select_console('log-console');
    $self->SUPER::post_fail_hook;
    $self->remount_tmp_if_ro;
    $self->export_logs_basic;
    # Export extra log after failure for further check gdm issue 1127317, also poo#45236 used for tracking action on Openqa
    $self->export_logs_desktop;
}

1;
