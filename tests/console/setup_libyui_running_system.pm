# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Module to set up the environment for using libyui REST API in the
# running system by installing libyui-rest-api packages.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "installbasetest";
use testapi;
use YuiRestClient;

sub run {
    select_console 'root-console';

    my $app = YuiRestClient::get_app(timeout => 60, interval => 1);
    my $port = $app->get_port();
    record_info('SERVER', "Used host for libyui: " . $app->get_host());
    record_info('PORT', "Used port for libyui: " . $port);
    set_var('YUI_PARAMS', YuiRestClient::get_yui_params_string($port));
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
