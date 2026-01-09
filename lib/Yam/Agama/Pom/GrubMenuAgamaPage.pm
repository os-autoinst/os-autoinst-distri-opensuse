# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles GRUB screen.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Yam::Agama::Pom::GrubMenuAgamaPage;
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

sub boot_from_hd {
    send_key_until_needlematch 'inst-bootmenu-boot-harddisk', 'down';
    send_key 'ret';
}

sub select_check_installation_medium_entry {
    my ($self) = @_;
    send_key_until_needlematch('grub-menu-agama-mediacheck-highlighted', 'down');
}

sub select_install_product {
    my ($self) = @_;
    send_key_until_needlematch($self->{tag_install_product}, 'down');
}

sub select_rescue_system_entry {
    send_key_until_needlematch('grub-menu-agama-rescue-system-highlighted', 'down');
}

sub edit_current_entry { shift->{grub_menu_base}->edit_current_entry() }

1;
