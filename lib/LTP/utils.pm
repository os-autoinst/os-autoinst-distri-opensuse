# Copyright © 2020 SUSE LLC
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

# Summary: LTP helper functions
# Maintainer: Martin Doucha <mdoucha@suse.cz>

package LTP::utils;

use base Exporter;
use strict;
use warnings;
use testapi;

our @EXPORT = qw(prepare_ltp_env);

# Set up basic shell environment for running LTP tests
sub prepare_ltp_env {
    my $ltp_env = get_var('LTP_ENV');

    assert_script_run('export LTPROOT=/opt/ltp; export LTP_COLORIZE_OUTPUT=n TMPDIR=/tmp PATH=$LTPROOT/testcases/bin:$PATH');

    # setup for LTP networking tests
    assert_script_run("export PASSWD='$testapi::password'");

    my $block_dev = get_var('LTP_BIG_DEV');
    if ($block_dev && get_var('NUMDISKS') > 1) {
        assert_script_run("lsblk -la; export LTP_BIG_DEV=$block_dev");
    }

    if ($ltp_env) {
        $ltp_env =~ s/,/ /g;
        script_run("export $ltp_env");
    }

    assert_script_run('cd $LTPROOT/testcases/bin');
}
