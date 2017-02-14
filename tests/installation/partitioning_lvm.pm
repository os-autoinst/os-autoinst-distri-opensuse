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
use parent qw(installation_user_settings y2logsstep);
use testapi;
use utils 'sle_version_at_least';

sub save_logs_and_resume {
    my $self = shift;
    $self->get_to_console;
    $self->save_upload_y2logs();
    select_console 'installation';
}

sub run {
    my $self             = shift;
    my $file_system_tags = [
        qw(
          partitioning-no-root-filesystem partitioning-encrypt-activated-existing
          partitioning-encrypt-ignored-existing
          )];
    my $collect_logs = 0;

    if (get_var('ENCRYPT_ACTIVATE_EXISTING')) {
        assert_screen $file_system_tags;
        if (match_has_tag('partitioning-no-root-filesystem')) {
            record_soft_failure 'bsc#989750';
            $collect_logs = 1;
        }
        elsif (match_has_tag('partitioning-encrypt-ignored-existing') and sle_version_at_least('12-SP4')) {
            record_soft_failure 'bsc#993247 https://fate.suse.com/321208';
            $collect_logs = 1;
        }

        unless (get_var('ENCRYPT_FORCE_RECOMPUTE')) {
            $self->save_logs_and_resume() if $collect_logs;
            return;
        }
    }

    # Storage NG introduces a new partitioning dialog. partitioning.pm detects this by the existence of the "Guided Setup" button
    # and sets the STORAGE_NG variable. This button uses a new hotkey.
    if (get_var("STORAGE_NG")) {
        send_key "alt-g";
    }
    else {
        send_key "alt-d";
    }

    my $numdisks = get_var("NUMDISKS");
    print "NUMDISKS = $numdisks\n";

    check_screen([qw(inst-partition-radio-buttons inst-partition-guided inst-partitioning-scheme)], 10);
    if (match_has_tag('inst-partition-radio-buttons')) {    # detect whether new (Radio Buttons) YaST behaviour
        if (get_var("ENCRYPT")) {
            send_key "alt-e";

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
        assert_screen [qw(partition-lvm-new-summary partitioning-encrypt-activated-existing partitioning-encrypt-broke-existing)];
        if (match_has_tag('partitioning-encrypt-broke-existing')) {
            record_soft_failure 'bsc#993249';
            $collect_logs = 1;
        }
    }
    elsif (get_var("STORAGE_NG")) {
        if ($numdisks <= 1) {
            die "Guided workflow does not skip disk selection when only one disk!"
                if !match_has_tag('inst-partitioning-scheme');
        }
        else {
            die "Guided workflow does skip disk selection when more than one disk! (NUMDISKS=$numdisks)"
                if !match_has_tag('inst-partition-guided');
            assert_screen "inst-partition-guided";       
            send_key 'alt-n';
            assert_screen "inst-select-root-disk";
            send_key 'alt-n';
        }
        send_key 'alt-e';
        assert_screen "inst-partitioning-lvm-enabled";
        if (get_var("ENCRYPT")) {
            send_key 'alt-a';

            if (!get_var('ENCRYPT_ACTIVATE_EXISTING')) {
                assert_screen 'inst-encrypt-password-prompt';
                #send_key 'tab'; # might be needed again later 
                type_password;
                send_key 'tab';
                type_password;
                send_key 'alt-n';
	        $self->await_password_check;
            }
        }
        else {
            send_key 'alt-n';
        }
        assert_screen "inst-filesystem-options";
        send_key 'alt-n';
        assert_screen [qw(partition-lvm-new-summary partitioning-encrypt-activated-existing partitioning-encrypt-broke-existing)];
        if (match_has_tag('partitioning-encrypt-broke-existing')) {
            record_soft_failure 'bsc#993249';
            $collect_logs = 1;
        }
	if (get_var("ENCRYPT")) {
            assert_screen "partitioning-encrypt-activated";
        }
    }
    elsif (!get_var('ENCRYPT_ACTIVATE_EXISTING')) {    # old behaviour still needed
        wait_screen_change { send_key "alt-l" };       # enable LVM-based proposal
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
