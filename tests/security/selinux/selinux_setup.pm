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
#
# Summary: Setup environment for selinux tests
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#40358

use base "consoletest";
use strict;
use testapi;
use utils;
use version_utils qw(is_sle is_leap);

sub run {
    select_console "root-console";

    # for opensuse, e.g, Tumbleweed, add the repo in case rather than by default
    if (!is_sle && !is_leap) {
        zypper_call("ar http://download.opensuse.org/tumbleweed/repo/oss/ tumbleweed-Oss");
    }

    # program 'sestatus' can be found in policycoreutils pkgs
    zypper_call("in policycoreutils");
    my $ret = script_run('zypper -n in policycoreutils-python');
    if ($ret) {
        if (defined $ret && $ret == 104) {
            record_soft_failure 'bsc#1116288 - package policycoreutils-python not found in module SLE-Module-Development-Tools';
        }
        else {
            die "Package policycoreutils-python installation failed";
        }
    }

    my $pkgs = script_output("echo `zypper se selinux | grep -i selinux | grep -v -w srcpackage | cut -d '|' -f 2`");
    zypper_call("in $pkgs", timeout => 3000);

    # for opensuse, e.g, Tumbleweed install selinux_policy pkgs as needed
    # for sle15 and sle15+ "selinux-policy-*" pkgs will not be released
    # NOTE: have to install "selinux-policy-minimum-*" pkg due to this bug: bsc#1108949
    if (!is_sle && !is_leap || is_sle('>=15')) {
        my @files = ("selinux-policy-20140730-103.3.noarch.rpm", "selinux-policy-minimum-20140730-103.3.noarch.rpm");
        foreach my $file (@files) {
            assert_script_run "wget --quiet " . data_url("selinux/$file");
            assert_script_run("rpm -ivh --nosignature --nodeps --noplugins $file");
        }
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
