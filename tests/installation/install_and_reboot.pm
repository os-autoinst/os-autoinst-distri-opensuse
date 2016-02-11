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
use bmwqemu ();

sub run() {
    my $self = shift;
    # NET isos are slow to install
    my $timeout = 2000;

    # workaround for yast popups
    my @tags = qw/rebootnow/;
    if (get_var("UPGRADE")) {
        push(@tags, "ERROR-removing-package");
        $timeout = 5500;    # upgrades are slower
    }
    while (1) {
        assert_screen \@tags, $timeout;

        if (match_has_tag("popup-warning")) {
            record_soft_failure;
            bmwqemu::diag "warning popup caused dent";
            send_key "ret";
            pop @tags;
            next;
        }
        # can happen multiple times
        if (match_has_tag("ERROR-removing-package")) {
            record_soft_failure;
            send_key 'alt-d';
            assert_screen 'ERROR-removing-package-details';
            send_key 'alt-i';
            assert_screen 'ERROR-removing-package-warning';
            send_key 'alt-o';
            next;
        }
        last;
    }

    send_key 'alt-s';    # Stop the reboot countdown

    select_console 'install-shell';

    $self->get_ip_address();
    $self->save_upload_y2logs();

    select_console 'installation';
    assert_screen 'rebootnow';

    if (get_var("LIVECD")) {

        # LiveCD needs confirmation for reboot
        send_key $cmd{"rebootnow"};
    }
    else {
        send_key 'alt-o';
    }

    #FIXME this block will go into a seperate reconnect_zkvm test after the refactoring of this test
    # on svirt we need to redefine the xml-file to boot the installed kernel
    if (check_var('BACKEND', 'svirt') && check_var('ARCH', 's390x')) {
        my $svirt = console('svirt');

        $svirt->change_domain_element(os => initrd  => undef);
        $svirt->change_domain_element(os => kernel  => undef);
        $svirt->change_domain_element(os => cmdline => undef);

        $svirt->change_domain_element(on_reboot => undef);

        $svirt->define_and_start;

        wait_serial("Welcome to SUSE Linux Enterprise Server", 300);
    }
}

1;
# vim: set sw=4 et:
