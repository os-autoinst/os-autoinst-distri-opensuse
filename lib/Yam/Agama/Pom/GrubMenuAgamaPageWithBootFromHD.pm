# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles GRUB screen with boot from hard disk option.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Yam::Agama::Pom::GrubMenuAgamaPageWithBootFromHD;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        grub_menu_base => $args->{grub_menu_base},
        tag_first_entry_highlighted => 'grub-menu-first-entry-highlighted',
        tag_install_product => 'grub-menu-install-product',
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    assert_screen($self->{tag_first_entry_highlighted}, 60);
}

sub select_install_product {
    my ($self) = @_;
    send_key_until_needlematch($self->{tag_install_product}, 'down');
}

sub boot_from_hd { shift->{grub_menu_base}->boot_from_hd() }
sub select_check_installation_medium_entry { shift->{grub_menu_base}->select_check_installation_medium_entry() }
sub edit_current_entry { shift->{grub_menu_base}->edit_current_entry() }
sub select_first_entry { shift->{grub_menu_base}->select_first_entry() }
sub select_rescue_system_entry { shift->{grub_menu_base}->select_rescue_system_entry() }

1;
