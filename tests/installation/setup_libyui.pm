# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Module to set up the environment for using libyui REST API with the
# installer, which requires enabling libyui-rest-api packages.

# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "installbasetest";
use Utils::Backends;
use Utils::Architectures;
use testapi;
use YuiRestClient;

sub run {
    my $app = YuiRestClient::get_app(installation => 1, timeout => 120, interval => 1);
    my $port = $app->get_port();
    record_info('SERVER', "Used host for libyui: " . $app->get_host());
    record_info('PORT', "Used port for libyui: " . $port);

    if (is_ssh_installation) {
        my $cmd = '';
        if (is_s390x) {
            if (is_svirt) {
                $cmd = 'TERM=linux ';
            }
        }
        $cmd .= YuiRestClient::get_yui_params_string($port) . " yast.ssh";
        enter_cmd($cmd);
    }
    $app->check_connection(timeout => 540, interval => 10);
}

1;
