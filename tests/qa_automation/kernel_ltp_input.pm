# Copyright (C) 2016 SUSE LLC
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

# G-Summary: [qa_automation] Add ltp tests
# G-Maintainer: Nathan Zhao <jtzhao@suse.com>

use base "qa_run";
use strict;
use warnings;
use testapi;

sub test_run_list {
    return qw(_reboot_off ltp_input);
}

sub test_suite {
    return 'kernel';
}

sub junit_type {
    return 'kernel_regression';
}

1;
