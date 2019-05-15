# Copyright © 2019 SUSE LLC
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
# Summary: Setup client system for krb5 cryptographic testing
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Ticket: poo#51560, poo#51569

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use lockapi;
use mmapi;
use krb5crypt;    # Import public variables

sub run {
    select_console 'root-console';

    mutex_wait('CONFIG_READY_KRB5_SERVER');
    krb5_init;
    mutex_create('TEST_DONE_CLIENT');
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
