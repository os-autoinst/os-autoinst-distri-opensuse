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
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    my $self             = shift;
    my $file_system_tags = [
        qw/
          partitioning-no-root-filesystem partitioning-encrypt-activated-existing
          partitioning-encrypt-ignored-existing
          /
    ];

    if (get_var('ENCRYPT_ACTIVATE_EXISTING')) {
        assert_screen $file_system_tags;
        if (match_has_tag('partitioning-no-root-filesystem')) {
            record_soft_failure 'bsc#989750';
        }
        elsif (match_has_tag('partitioning-encrypt-ignored-existing')) {
            record_soft_failure 'bsc#993247';
        }

        return unless get_var 'ENCRYPT_FORCE_RECOMPUTE';
    }

    send_key "alt-d";

    if (check_screen('inst-partition-radio-buttons', 10)) {    # detect whether new (Radio Buttons) YaST behaviour
        if (get_var("ENCRYPT")) {
            send_key 'alt-e';
            if (!get_var('ENCRYPT_ACTIVATE_EXISTING')) {
                assert_screen 'inst-encrypt-password-prompt';
                type_password;
                send_key 'tab';
                type_password;
                send_key 'ret';
            }
            assert_screen 'partitioning-encrypt-selected-cryptlvm';
        }
        else {
            send_key 'alt-l';
        }
        send_key 'alt-o';
        assert_screen [qw/partition-lvm-new-summary partitioning-encrypt-activated-existing partitioning-encrypt-broke-existing/];
        if (match_has_tag('partitioning-encrypt-broke-existing')) {
            record_soft_failure 'bsc#993249';
        }
    }
    elsif (!get_var('ENCRYPT_ACTIVATE_EXISTING')) {    # old behaviour still needed
        send_key "alt-l", 1;                           # enable LVM-based proposal
        if (get_var("ENCRYPT")) {
            send_key "alt-y";
            assert_screen "inst-encrypt-password-prompt";
            type_password;
            send_key "tab";
            type_password;
            send_key "ret";
            assert_screen "partition-cryptlvm-summary";
        }
        else {
            assert_screen "partition-lvm-summary";
        }
        send_key "alt-o";
    }
}

1;
# vim: set sw=4 et:
