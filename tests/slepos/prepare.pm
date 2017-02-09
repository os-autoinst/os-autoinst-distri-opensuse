# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic SLEPOS test
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils;
use mm_network;
use lockapi;

sub run() {
    set_var('ORGANIZATION', "myorg");
    set_var('COUNTRY',      "us");
    set_var('ADMINPASS',    "adminpass");
    set_var('SSL',          get_var('SSL') ? "yes" : "no");
    if (get_var('SLEPOS') =~ /^branchserver/) {
        set_var('ORGANIZATIONAL_UNIT', "myorgunit1");
        set_var('LOCATION',            "mybranch1");
        set_var('USER_PASSWORD',       "branchpass");
    }
    elsif (get_var('SLEPOS') =~ /^combo/) {
        set_var('ORGANIZATIONAL_UNIT', "myorgunit1");
        set_var('LOCATION',            "mycombobranch");
        set_var('USER_PASSWORD',       "branchpass");
    }

    if (get_var('IP_BASED')) {
        set_var('ADMINSERVER_ADDR', "10.0.2.15");
        if (get_var('SLEPOS') =~ /^branchserver/) {
            set_var('MY_ADDR', "10.0.2.210");
        }
        elsif (get_var('SLEPOS') =~ /^adminserver|^combo/) {
            set_var('MY_ADDR', "10.0.2.15");
        }
    }
    else {
        set_var('MY_ADDR', get_var('SLEPOS') . ".openqa.test");
        if (get_var('SLEPOS') =~ /^branchserver/) {
            set_var('ADMINSERVER_ADDR', "adminserver.openqa.test");
        }
        elsif (get_var('SLEPOS') =~ /^adminserver/) {
            set_var('ADMINSERVER_ADDR', get_var('SLEPOS') . ".openqa.test");
        }
        elsif (get_var('SLEPOS') =~ /^combo/) {
            set_var('ADMINSERVER_ADDR', get_var('SLEPOS') . ".openqa.test");
        }
    }



    # let's see how it looks at the beginning
    save_screenshot;

    # init
    select_console 'root-console';

    # Stop packagekit
    script_run "chmod 444 /usr/sbin/packagekitd";    # packagekitd will be not executed

    configure_hostname(get_var('SLEPOS'));
    if (get_var('IP_BASED')) {
        configure_default_gateway;
        configure_static_ip(get_var('MY_ADDR') . "/24");
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
