# Copyright (C) 2019 SUSE LLC
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
# Summary: Test with "FIPS" installed and enabled, the WWW browser "links"
#          can access https web pages successfully.
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#52289, tc#1621467

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use web_browser qw(setup_web_browser_env run_web_browser_text_based);

sub run {
    select_console "root-console";
    setup_web_browser_env();
    zypper_call("--no-refresh --no-gpg-checks in links");
    run_web_browser_text_based("links", undef);
}

1;
