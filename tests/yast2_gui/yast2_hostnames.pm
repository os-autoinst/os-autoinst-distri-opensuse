# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast2_hostnames check hostnames and add/delete hostsnames
#    Make sure those yast2 modules can opened properly. We can add more
#    feature test against each module later, it is ensure it will not crashed
#    while launching atm.
# Maintainer: Zaoliang Luo <zluo@suse.com>

use base "y2x11test";
use strict;
use testapi;

sub run() {
    my $self   = shift;
    my $module = "host";

    select_console 'root-console';
    #	add 1 entry to /etc/hosts and edit it later
    script_run "echo '10.160.1.100    dist.suse.de dist' >> /etc/hosts";
    select_console 'x11', await_console => 0;

    $self->launch_yast2_module_x11($module);

    assert_and_click "yast2_hostnames_added";
    send_key 'alt-i';
    send_key 'alt-t';
    type_string 'download-srv';
    send_key 'alt-h';
    type_string 'download.opensuse.org';
    send_key 'alt-i';
    type_string '195.135.221.134';
    assert_and_click 'yast2_hostnames_changed_ok';
    assert_screen "yast2-$module-ui", 30;
    #	OK => Exit
    send_key "alt-o";
}

1;
# vim: set sw=4 et:
