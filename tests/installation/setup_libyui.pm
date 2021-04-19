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

# Summary: Module to set up the environment for using libyui REST API with the
# installer, which requires enabling libyui-rest-api packages.

# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "installbasetest";
use testapi;
use Utils::Backends qw(is_hyperv);
use YuiRestClient;
use YuiRestClient::Wait;

sub run {
    my $ip_regexp = qr/(?<ip>(\d+\.){3}\d+)/i;
    if (is_hyperv) {
        my $boot_timeout = 500;
        my $svirt        = select_console('svirt');
        my $name         = $svirt->name;
        my $cmd          = "powershell -Command \"Get-VM -Name $name | Select -ExpandProperty Networkadapters | Select IPAddresses\"";
        my $ip           = YuiRestClient::Wait::wait_until(object => sub {
                my $ip = $svirt->get_cmd_output($cmd);
                return $+{ip} if ($ip =~ $ip_regexp);
        }, timeout => $boot_timeout, interval => 30);
        set_var('YUI_SERVER', $ip);
        #        select_console('sut', await_console => 0);
    } elsif (check_var('BACKEND', 's390x')) {
        select_console('install-shell');
        my $ip = YuiRestClient::Wait::wait_until(object => sub {
                my $ip = script_output('ip -o -4 addr list | sed -n 2p | awk \'{print $4}\' | cut -d/ -f1', proceed_on_failure => 1);
                return $+{ip} if ($ip =~ $ip_regexp);
        });
        set_var('YUI_SERVER', $ip);
    } elsif (check_var('VIRSH_VMM_FAMILY', 'xen')) {
        assert_screen "inst-betawarning", 500;
        select_console('root-console');
        my $ip = YuiRestClient::Wait::wait_until(object => sub {
                my $ip = script_output('ip -o -4 addr list | sed -n 2p | awk \'{print $4}\' | cut -d/ -f1', proceed_on_failure => 1);
                return $+{ip} if ($ip =~ $ip_regexp);
        });
        set_var('YUI_SERVER', $ip);
    }
    YuiRestClient::connect_to_app();
    select_console('installation');
}

1;
