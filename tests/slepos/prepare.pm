# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "basetest";
use testapi;
use utils;
use mm_network;
use lockapi;

sub run() {
    my $self = shift;


    set_var('ORGANIZATION', "myorg");
    set_var('COUNTRY',      "us");
    set_var('ADMINPASS',    "adminpass");
    set_var('SSL',          get_var('SSL') ? "yes" : "no");
    if (get_var('SLEPOS') =~ /^branchserver/) {
        set_var('ORGANIZATIONAL_UNIT', "myorgunit1");
        set_var('LOCATION',            "mybranch1");
        set_var('USER_PASSWORD',       "branchpass");
    }

    if (get_var('IP_BASED')) {
        set_var('ADMINSERVER_ADDR', "10.0.2.15/24");
        if (get_var('SLEPOS') =~ /^branchserver/) {
            set_var('MY_ADDR', "10.0.2.210/24");
        }
        elsif (get_var('SLEPOS') =~ /^adminserver/) {
            set_var('MY_ADDR', "10.0.2.15/24");
        }
    }
    else {
        set_var('ADMINSERVER_ADDR', "adminserver.openqa.test");
        if (get_var('SLEPOS') =~ /^branchserver/) {
            set_var('MY_ADDR', "branchserver.openqa.test");
        }
        elsif (get_var('SLEPOS') =~ /^adminserver/) {
            set_var('MY_ADDR', "adminserver.openqa.test");
        }
    }



    # let's see how it looks at the beginning
    save_screenshot;

    # init
    select_console 'root-console';

    configure_hostname(get_var('SLEPOS'));
    if (get_var('IP_BASED')) {
        configure_default_gateway;
        configure_static_ip(get_var('MY_ADDR'));
        configure_static_dns(get_host_resolv_conf());
    }
    else {
        # on standalone image server with qemu network we don't have to wait
        if (get_var('NICTYPE') eq 'tap') {
            mutex_lock('dhcp');
            mutex_unlock('dhcp');
        }
        configure_dhcp();
    }
    save_screenshot;
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
