# Copyright 2020-2022 SUSE LLC
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
use version_utils 'is_sle';

sub run {
    die 'Leap 15.2 and below and SLE 15-SP2 and below do not have libyui-REST, exit now.' if (is_sle('<=15-SP2') || is_leap('<=15.2'));
    die 'Module requires YUI_REST_API variable to be set.', unless get_var('YUI_REST_API');
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
        if (check_var('VIDEOMODE', 'ssh-x')) {
            $cmd .= 'QT_XCB_GL_INTEGRATION=none ';
        }
        $cmd .= YuiRestClient::get_yui_params_string($port) . " yast.ssh";
        enter_cmd($cmd);
    }
    $app->check_connection(timeout => 540, interval => 10);
}

1;
