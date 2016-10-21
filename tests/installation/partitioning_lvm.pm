# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Partition selection and configuration based on LVM proposal, also
#   cryptlvm
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub save_logs_and_resume {
    my $self = shift;
    $self->get_to_console;
    $self->save_upload_y2logs();
    select_console 'installation';
}

sub run() {
    my $self             = shift;
    my $file_system_tags = [
        qw/
          partitioning-no-root-filesystem partitioning-encrypt-activated-existing
          partitioning-encrypt-ignored-existing
          /
    ];
    my $collect_logs = 0;

    if (get_var('ENCRYPT_ACTIVATE_EXISTING')) {
        assert_screen $file_system_tags;
        if (match_has_tag('partitioning-no-root-filesystem')) {
            record_soft_failure 'bsc#989750';
            $collect_logs = 1;
        }
        elsif (match_has_tag('partitioning-encrypt-ignored-existing')) {
            record_soft_failure 'bsc#993247 https://fate.suse.com/321208';
            $collect_logs = 1;
        }

        unless (get_var('ENCRYPT_FORCE_RECOMPUTE')) {
            $self->save_logs_and_resume() if $collect_logs;
            return;
        }
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
            $collect_logs = 1;
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

    $self->save_logs_and_resume() if $collect_logs;
}

1;
# vim: set sw=4 et:
