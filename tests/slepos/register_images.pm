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
use lockapi;

sub run() {
    my $self = shift;

    assert_script_run "registerImages --ldap --move --include-boot /var/lib/SLEPOS/system/images/minimal-3.4.0/";
    assert_script_run "registerImages --gzip --ldap /var/lib/SLEPOS/system/images/graphical-3.4.0";

    assert_script_run "curl " . autoinst_url . "/data/slepos/xorg.conf > /srv/SLEPOS/config/xorg.conf";
    assert_script_run "posAdmin.pl --base cn=graphical,cn=default,cn=global,o=myorg,c=us --add --scConfigFileTemplate --cn xorg_conf --scConfigFile '/etc/X11/xorg.conf' --scMust TRUE --scBsize 1024 --scConfigFileData /srv/SLEPOS/config/xorg.conf";
    mutex_create("images_registered");
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
