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
#
# Summary: switch from CC_STACKPROTECTOR to CC_STACKPROTECTOR_STRONG in the kernel.
# This provides better protection against stack based buffer overflows.
# The feature is not included in s390x platform yet.
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#64084, tc#1744070

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    # check the kernel configuration file to make sure the parameter is there
    validate_script_output "cat /boot/config-`uname -r`|grep CONFIG_STACKPROTECTOR", qr/CONFIG_STACKPROTECTOR_STRONG=y/;
}

1;
