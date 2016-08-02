# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "y2logsstep";
use testapi;
use utils qw/assert_screen_with_soft_timeout/;

sub run() {
    my $self = shift;

    if (get_var('ENCRYPT')) {
        assert_screen "upgrade-unlock-disk";
        send_key 'alt-p';    # provide password
        assert_screen "upgrade-enter-password";
        type_password;
        send_key $cmd{ok};
    }

    # hardware detection and waiting for updates from suse.com can take a while
    assert_screen_with_soft_timeout('select-for-update', timeout => 500, soft_timeout => 100, bugref => 'bsc#990254');
    send_key $cmd{next}, 1;
    assert_screen "remove-repository", 100;
    send_key $cmd{next}, 1;
    if (check_var('DISTRI', 'opensuse')) {
        if (check_screen('network-not-configured', 5)) {
            send_key 'alt-n';
            if (check_screen('ERROR-cannot-download-repositories')) {
                send_key 'alt-o';
                record_soft_failure 'error can not download repositories';
            }
        }
        if (check_screen('list-of-online-repositories', 10)) {
            send_key 'alt-n';
            record_soft_failure;
        }
        if (get_var("BETA")) {
            assert_screen "inst-betawarning";
            send_key 'alt-o';
        }
        # Bug 881107 - there is 2nd license agreement screen in openSUSE upgrade
        # http://bugzilla.opensuse.org/show_bug.cgi?id=881107
        if (check_screen('upgrade-license-agreement', 10)) {
            send_key 'alt-n';
        }
        if (check_screen('installed-product-incompatible', 10)) {
            send_key 'alt-o';    # C&ontinue
            record_soft_failure 'installed product incompatible';
        }

        assert_screen "update-installation-overview", 15;
    }
}

1;
# vim: set sw=4 et:
