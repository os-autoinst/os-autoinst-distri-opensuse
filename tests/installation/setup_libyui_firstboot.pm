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

# Summary: Enable libyui for firstboot. Temporary module until
# https://progress.opensuse.org/issues/90368 is done.

# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "installbasetest";
use registration "add_suseconnect_product";
use version_utils "is_sle";
use utils qw(zypper_call);
use YuiRestClient;
use testapi;
use Utils::Firewalld qw(add_port_to_zone);

sub run {
    add_suseconnect_product('sle-module-development-tools') if is_sle;
    zypper_call('in libyui-rest-api');
    my $app  = YuiRestClient::get_app();
    my $port = $app->get_port();
    record_info('SERVER', "Used host for libyui: " . $app->get_host());
    record_info('PORT',   "Used port for libyui: " . $port);
    # Add the port to permanent config and restart firewalld to apply the changes immediately.
    # This is needed, because if firewall is restarted for some reason, then the port become
    # closed (e.g. it was faced while saving settings in yast2 lan) and further tests will not
    # be able to communicate with YaST modules.
    add_port_to_zone($port, 'public');
    foreach my $export ("YUI_HTTP_PORT=$port", "YUI_HTTP_REMOTE=1", "YUI_REUSE_PORT=1", "Y2DEBUG=1") {
        assert_script_run "echo export $export >> /usr/lib/YaST2/startup/Firstboot-Stage/S01-rest-api";
    }
    assert_script_run "chmod +x /usr/lib/YaST2/startup/Firstboot-Stage/S01-rest-api";
}

1;
