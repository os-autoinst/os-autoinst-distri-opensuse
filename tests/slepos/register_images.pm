# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic SLEPOS test for registering images
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "basetest";
use testapi;
use utils;
use lockapi;

sub run {
    assert_script_run "registerImages --ldap --move --include-boot /var/lib/SLEPOS/system/images/minimal-3.4.0/";
    assert_script_run "registerImages --gzip --ldap /var/lib/SLEPOS/system/images/graphical-3.4.0";

    assert_script_run "curl " . autoinst_url . "/data/slepos/xorg.conf > /srv/SLEPOS/config/xorg.conf";
    assert_script_run
"posAdmin.pl --base cn=graphical,cn=default,cn=global,o=myorg,c=us --add --scConfigFileTemplate --cn xorg_conf --scConfigFile '/etc/X11/xorg.conf' --scMust TRUE --scBsize 1024 --scConfigFileData /srv/SLEPOS/config/xorg.conf";
    mutex_create("images_registered");
}

sub test_flags {
    return {fatal => 1};
}

1;
