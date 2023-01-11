# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Enable libyui for firstboot. Temporary module until
# https://progress.opensuse.org/issues/90368 is done.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "installbasetest";
use YuiRestClient;
use testapi;

sub run {
    my $app = YuiRestClient::get_app();
    my $port = $app->get_port();
    record_info('SERVER', "Used host for libyui: " . $app->get_host());
    record_info('PORT', "Used port for libyui: " . $port);
    foreach my $export ("YUI_HTTP_PORT=$port", "YUI_HTTP_REMOTE=1", "YUI_REUSE_PORT=1", "Y2DEBUG=1") {
        assert_script_run "echo export $export >> /usr/lib/YaST2/startup/Firstboot-Stage/S01-rest-api";
    }
    assert_script_run "chmod +x /usr/lib/YaST2/startup/Firstboot-Stage/S01-rest-api";
}

1;
