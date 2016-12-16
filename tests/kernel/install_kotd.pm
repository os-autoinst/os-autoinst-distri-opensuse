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

# Summary:  [qa_automation] kernel of the day testing libs
# Maintainer: Nathan Zhao <jtzhao@suse.com>

package install_kotd;
use strict;
use utils;
use testapi;

# Add kotd repo
# KOTD_RELEASE is the version of operating system, such as openSUSE-42.2, SLE12-SP3
sub kotd_addrepo {
    my $release = get_var("KOTD_RELEASE");
    my $url     = "http://download.suse.de/ibs/Devel:/Kernel:/$release/standard/";
    zypper_call("--no-gpg-check ar -f '$url' kotd", timeout => 600);
    zypper_call("--gpg-auto-import-keys ref",       timeout => 1200);
}

# Install kotd kernel
sub kotd_install {
    my $output = script_output("zypper -n up kernel-default");
    if ($output =~ /(?<='zypper install )([^']+)/) {
        zypper_call("install $1", timeout => 1200);
    }
    else {
        die "Failed to install kernel of the day";
    }
}

# Reboot system and login
sub kotd_reboot {
    type_string("reboot\n");
    wait_boot;
    reset_consoles();
    select_console("root-console");
}

1;
