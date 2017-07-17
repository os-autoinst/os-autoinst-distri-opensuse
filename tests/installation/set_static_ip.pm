# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Change static IP address of the image to reboot correctly
# Maintainer: Matthias Griessmeier <mgriessmeier@suse.com>

use base "y2logsstep";
use strict;
use testapi;

sub run {
    select_console 'install-shell';

    my $ip    = get_var('VIRSH_GUEST');
    my $ifcfg = "/mnt/etc/sysconfig/network/ifcfg-eth0";

    script_run("cat $ifcfg");
    script_run("sed -i -e \"/IPADDR=.*\$/s\@\@IPADDR=\'$ip/20\'\@\" $ifcfg");
    assert_script_run("cat $ifcfg | grep $ip", fail_message => 'IP address was not changed');

    select_console 'installation';
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
