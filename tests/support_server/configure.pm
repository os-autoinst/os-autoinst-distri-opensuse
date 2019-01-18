# Copyright (C) 2015-2018 SUSE Linux GmbH
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

# Summary: configure support server repos during image building
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use strict;
use warnings;
use base 'basetest';
use testapi;

sub run {
    # this is supposed to run during SUPPORTSERVER_GENERATOR
    #
    # remove the installation media
    my $script = "
    zypper lr
    zypper rr 1
    ";

    # optionally add network repos
    if (get_var("POOL_REPO")) {
        $script .= "zypper -n --no-gpg-checks ar --refresh '" . get_var("POOL_REPO") . "' pool\n";
    }

    if (get_var("UPDATES_REPO")) {
        $script .= "zypper -n --no-gpg-checks ar --refresh '" . get_var("UPDATES_REPO") . "' updates\n";
    }

    if (get_var("SLENKINS_TESTSUITES_REPO")) {
        $script .= "zypper -n --no-gpg-checks ar --refresh '" . get_var("SLENKINS_TESTSUITES_REPO") . "' slenkins_testsuites\n";
    }

    if (get_var("SLENKINS_REPO")) {
        $script .= "zypper -n --no-gpg-checks ar --refresh '" . get_var("SLENKINS_REPO") . "' slenkins\n";
    }

    script_output($script);
}

sub test_flags {
    return {fatal => 1};
}

1;

