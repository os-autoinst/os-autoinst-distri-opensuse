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
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use base "consoletest";
use testapi;

sub run() {
    become_root();

    # can't use assert_script_run as zypper patch returns different return
    # values
    script_run("zypper -n patch --with-interactive -l -r incident0; echo zypper-patch-\$?- > /dev/$serialdev", 0);
    $ret = wait_serial "zypper-patch-\?-", 300;
    $ret =~ /zypper-patch-(\d+)/;
    die "zypper failed with code $1" unless $1 == 0 || $1 == 102 || $1 == 103;

    type_string "exit\n";
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
