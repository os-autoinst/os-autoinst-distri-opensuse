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
use version_utils 'is_caasp';

use strict;
use testapi;
use caasp 'unpause';

# Fill certificate information
sub velum_config {
    assert_screen 'velum-certificates-page';

    # Internal Dashboard FQDN/IP is pre-filled
    for (1 .. 5) { send_key 'tab' }

    # Install Tiller
    send_key 'spc';

    # Select container runtime
    if (check_var('CONTAINER_RUNTIME', 'cri-o')) {
        send_key 'pgdn';
        assert_and_click 'container-runtime-cri-o';
        wait_still_screen 3;
    }

    # Make sure next button is visible
    send_key 'pgdn';
    assert_and_click "velum-next";

    assert_screen 'velum-tips-page';
    assert_and_click "velum-next";

    unpause 'VELUM_CONFIGURED';
}

# Upload autoyast profile
sub upload_autoyast {
    switch_to 'xterm';
    assert_script_run "curl --location $admin_fqdn/autoyast --output autoyast.xml";
    upload_logs('autoyast.xml');
    switch_to 'velum';
}

sub run {
    x11_start_program("firefox $admin_fqdn", target_match => 'firefox-url-loaded');
    send_key 'f11';
    wait_still_screen 3;

    confirm_insecure_https if is_caasp('VMX');

    # Check that footer has proper tag
    my $v = get_var('VERSION');
    $v .= '-dev' if check_var('BETA', 'DEV');
    assert_screen "velum-footer-version-$v";

    # Register to velum
    assert_and_click 'create-an-account';
    assert_screen 'velum-signup';
    velum_login(1);

    velum_config;       # Login and configure cluster
    upload_autoyast;    # Upload the logs of autoyast (if any)
}

1;

