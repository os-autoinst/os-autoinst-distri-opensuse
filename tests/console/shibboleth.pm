# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: shibboleth-sp apache2 curl
# Summary: Shibboleth SSO test
# - Install shibboleth-sp apache2
# - Enable shib module on apache2
# - Restart apache
# - Run "curl --no-buffer http://localhost/Shibboleth.sso/Status | grep 'Cannot connect to shibd process'"
# - Run "curl --no-buffer http://localhost/Shibboleth.sso/Session | grep 'A valid session was not found.'"
# - Disable shib module on apache2
# Maintainer: Romanos Dodopoulos <romanos.dodopoulos@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    zypper_call "in shibboleth-sp apache2";
    assert_script_run "a2enmod shib";
    systemctl 'restart apache2';

    script_run "curl --no-buffer http://localhost/Shibboleth.sso/Status";
    assert_script_run "curl --no-buffer http://localhost/Shibboleth.sso/Status | grep 'Cannot connect to shibd process'";

    assert_script_run "curl --no-buffer http://localhost/Shibboleth.sso/Session | grep 'A valid session was not found.'";

    assert_script_run "a2dismod shib";
}

1;
