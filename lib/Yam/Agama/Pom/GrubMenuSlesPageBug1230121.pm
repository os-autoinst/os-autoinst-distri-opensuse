# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles grub screen in SLES 16 for bug bsc#1230121.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::GrubMenuSlesPageBug1230121;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        grub_menu_base => $args->{grub_menu_base},
        tag_first_entry_highlighted => 'grub-menu-sles16-highlighted',
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    assert_screen($self->{tag_first_entry_highlighted}, 60);
}

sub edit_current_entry { shift->{grub_menu_base}->edit_current_entry() }

sub select_first_entry {
    my ($self) = @_;
    record_soft_failure("bsc#1230121 - Agama-live SLES-16 Alpha installation. Unable to login after installation");
    $self->edit_current_entry();
    send_key_until_needlematch('linux-line-selected', 'down', 26);
    wait_screen_change { send_key('end') };
    wait_still_screen(1);
    send_key('backspace');
    type_string('0');
    wait_still_screen(1);
    save_screenshot;
    send_key('ctrl-x');
}

1;
