# Copyright © 2017 SUSE LLC
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

# Summary:  xfstests testsuite
# Use the latest xfstests testsuite from upstream to make file system test
# Maintainer: Yong Sun <yosun@suse.com>

use base "xfstests_install";
use base "xfstests_device";
use base "xfstests_logs";
use strict;
use warnings;
use testapi;

sub run() {
    my $self = shift;
    my @blst = split(/,/, get_var('XFSTESTS_KNOWN_ISSUE', ''));
    foreach my $case (@blst) {
        if ($case !~ /^-/) {
            script_run("mv /tmp/issue_case/$case ./tests/$case");
            script_run("./check $case", 60 * 60 * 1);
        }
    }

    # Upload all log tarballs in ./results/
    $self->log_upload();
}

1;
