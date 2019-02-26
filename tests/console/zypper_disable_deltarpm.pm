# Copyright (C) 2015 SUSE Linux GmbH
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

# Summary: test to disable deltarpm
#    installing all online updates takes too long if deltarpm is on and our
#    line is powerful enough to download full rpms.
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    assert_script_run "echo 'download.use_deltarpm = false' >> /etc/zypp/zypp.conf";
}

sub test_flags {
    return {fatal => 1};
}

1;
