# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles GRUB screen.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::GrubMenuAgamaPage;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        grub_menu_base => $args->{grub_menu_base},
        tag_agama_installer_highlighted => 'grub-menu-agama-installer-highlighted',
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    send_key_until_needlematch($self->{tag_agama_installer_highlighted}, 'down') unless check_screen($self->{tag_agama_installer_highlighted}, 10);
    assert_screen($self->{tag_agama_installer_highlighted}, 60);
}

sub boot_from_hd {
    send_key_until_needlematch 'inst-bootmenu-boot-harddisk', 'down';
    send_key 'ret';
}

sub select_check_installation_medium_entry {
    my ($self) = @_;
    send_key_until_needlematch('grub-menu-agama-mediacheck-highlighted', 'down');
}

sub select_rescue_system_entry {
    send_key_until_needlematch('grub-menu-agama-rescue-system-highlighted', 'down');
}

sub edit_current_entry { shift->{grub_menu_base}->edit_current_entry() }

1;
