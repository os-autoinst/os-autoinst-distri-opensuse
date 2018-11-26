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
use version_utils 'is_storage_ng';
use partition_setup 'enable_encryption_guided_setup';

sub save_logs_and_resume {
    my $self = shift;
    $self->get_to_console;
    $self->save_upload_y2logs();

    # cleanup
    type_string "cd /\n";
    type_string "reset\n";
    select_console 'installation';
}

sub run {
    my $self             = shift;
    my $file_system_tags = [
        qw(
          partitioning-encrypt-activated-existing
          partitioning-encrypt-ignored-existing
          )];

    if (get_var('ENCRYPT_ACTIVATE_EXISTING')) {
        assert_screen $file_system_tags;
        if (match_has_tag('partitioning-encrypt-ignored-existing')) {
            record_info 'bsc#993247 https://fate.suse.com/321208', 'activated encrypted partition will not be recreated as encrypted';
        }
        return unless (get_var('ENCRYPT_FORCE_RECOMPUTE'));
    }

    # Storage NG introduces a new partitioning dialog. partitioning.pm detects this by the existence of the "Guided Setup" button
    # and sets the STORAGE_NG variable. This button uses a new hotkey.
    send_key $cmd{guidedsetup};

    my $numdisks = get_var("NUMDISKS");
    print "NUMDISKS = $numdisks\n";

    assert_screen [qw(inst-partition-radio-buttons inst-partition-guided inst-partitioning-scheme inst-select-disk-to-use-as-root )];
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
        assert_screen [qw(partition-lvm-new-summary partitioning-encrypt-activated-existing)];
    }
    elsif (is_storage_ng) {
        send_key $cmd{next} if (match_has_tag('inst-select-disk-to-use-as-root'));

        send_key $cmd{enablelvm};
        assert_screen "inst-partitioning-lvm-enabled";
        if (get_var("ENCRYPT")) {
            enable_encryption_guided_setup;
        }
        else {
            send_key $cmd{next};
        }
        assert_screen "inst-filesystem-options";
        send_key 'alt-n';
        assert_screen [qw(partition-lvm-new-summary partitioning-encrypt-activated-existing)];
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
}

1;
