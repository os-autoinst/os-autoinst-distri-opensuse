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

# Summary: Modules sets up the environment for using libyui REST API with the
# installer, which requires enabling libyui-rest-api packages.

# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "installbasetest";
use testapi;

use YuiRestClient;
use YuiRestClient::App;
use YuiRestClient::Http::HttpClient;

sub run {
    record_info('PORT', "Used port for libyui: " . get_var('YUI_PORT'));
    assert_screen('startshell', timeout => 500);
    assert_script_run('extend libyui-rest-api');
    type_string "exit\n";
    my $port = get_var('YUI_PORT');
    my $host = get_var('YUI_SERVER');
    my $app  = YuiRestClient::App->new({port => $port, host => $host});
    # As we start installer, REST API is not instantly available
    $app->connect(timeout => 500, interval => 10);
    YuiRestClient::set_app($app);
}

1;
