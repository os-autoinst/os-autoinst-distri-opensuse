# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Login to velum and fill initial configuration
# Maintainer: Martin Kravec <mkravec@suse.com>

use parent 'caasp_controller';
use caasp_controller;
use caasp 'get_admin_job';

use strict;
use testapi;
use lockapi;

# Fill certificate information
sub velum_config {
    assert_screen 'velum-certificates-page';

    # Internal Dashboard FQDN/IP is pre-filled
    for (1 .. 5) { send_key 'tab' }

    # Install Tiller
    send_key 'spc';

    # Make sure next button is visible
    send_key 'pgdn';
    assert_and_click "velum-next";

    assert_screen 'velum-tips-page';
    assert_and_click "velum-next";

    mutex_create 'VELUM_CONFIGURED';
}

# Upload autoyast profile
sub upload_autoyast {
    send_key 'alt-tab';    # switch to xterm
    assert_screen 'xterm';
    assert_script_run 'curl --location ' . get_var('DASHBOARD_URL') . '/autoyast' . ' --output autoyast.xml';
    upload_logs('autoyast.xml');
    send_key 'alt-tab';    # switch to xterm
}

sub run {
    # Wait until dashboard becomes ready
    mutex_lock "VELUM_STARTED", get_admin_job;
    mutex_unlock "VELUM_STARTED";

    # Display velum dashboard
    type_string get_var('DASHBOARD_URL');
    send_key 'ret';
    send_key "f11";
    confirm_insecure_https;

    # Check that footer has proper tag
    my $v = get_var('VERSION');
    $v .= '-dev' if get_var 'BETA';
    assert_screen "velum-footer-version-$v";

    # Register to velum
    assert_and_click 'create-an-account';
    assert_screen 'velum-signup';
    velum_login(1);

    # Login and configure cluster
    velum_config;

    # Upload the logs of autoyast (if any)
    upload_autoyast;

}

1;

