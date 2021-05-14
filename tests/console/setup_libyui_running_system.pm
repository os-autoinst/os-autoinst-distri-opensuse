# Copyright © 2021 SUSE LLC
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

# Summary: Module to set up the environment for using libyui REST API in the
# running system by installing libyui-rest-api packages.

# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "installbasetest";
use testapi;
use YuiRestClient;

sub run {
    select_console 'root-console';

    my $app  = YuiRestClient::get_app();
    my $port = $app->get_port();
    record_info('SERVER', "Used host for libyui: " . $app->get_host());
    record_info('PORT',   "Used port for libyui: " . $port);
    set_var('YUI_PARAMS', YuiRestClient::get_yui_params_string($port));
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
