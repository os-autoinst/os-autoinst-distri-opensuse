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

package kotd;
use strict;
use base "opensusebasetest";
use utils;
use testapi;

sub kotd_addrepo {
    my ($self, $url) = @_;
    assert_script_run("zypper --no-gpg-check -n ar -f '$url' kotd", 600);
    assert_script_run("zypper --gpg-auto-import-keys ref",          600);
}

sub kotd_install {
    my $self   = shift;
    my $output = script_output("zypper -n up kernel-default");
    if ($output =~ /(?<='zypper install )([^']+)/) {
        assert_script_run("zypper -n install $1", 1200);
    }
    else {
        die "Failed to install kernel of the day";
    }
}

sub kotd_reboot {
    my $self = shift;
    type_string("reboot\n");
    wait_boot;
    reset_consoles();
    select_console("root-console");
}

1;
