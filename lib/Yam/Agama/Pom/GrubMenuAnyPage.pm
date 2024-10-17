# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles GRUB screen.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::GrubMenuAnyPage;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        tag_first_entry_highlighted => ['grub-menu-agama-installer-highlighted',
            'grub-menu-openSUSE-leap-highlighted',
            'grub-menu-sles16-highlighted',
            'grub-menu-openSUSE-Tumbleweed-highlighted'],
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    assert_screen($self->{tag_first_entry_highlighted}, 60);
}

sub boot_from_hd {
    if (match_has_tag('grub-menu-agama-installer-highlighted')) {
        send_key_until_needlematch 'inst-bootmenu-boot-harddisk', 'down';
        send_key 'ret';
    }
}

1;
