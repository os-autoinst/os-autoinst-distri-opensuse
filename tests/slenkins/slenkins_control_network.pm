# Copyright 2015-2016 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: alternative setup for running independent slenkins control node without support server
#   normally, this is done as part of support server setup
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use strict;
use warnings;
use base 'basetest';
use testapi;
use lockapi;
use mmapi;
use mm_network;

sub run {
    configure_default_gateway;
    configure_static_ip(ip => '10.0.2.1/24');
    configure_static_dns(get_host_resolv_conf());
    restart_networking();

    script_output("
        zypper -n --no-gpg-checks ar '" . get_var('SLENKINS_TESTSUITES_REPO') . "' slenkins_testsuites
        zypper -n --no-gpg-checks ar '" . get_var('SLENKINS_REPO') . "' slenkins
    ", 100);
}

sub test_flags {
    return {fatal => 1};
}

1;

