# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles grub screen in SLES 16.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::GrubMenuSlesPage;
use strict;
use warnings;
use testapi;

use Utils::Architectures;

sub new {
    my ($class, $args) = @_;
    return bless {
        grub_menu_base => $args->{grub_menu_base},
        tag_first_entry_highlighted => 'grub-menu-sles16-highlighted',
        tag_first_entry_highlighted_hmc_ppc64le => 'grub-menu-hmc_ppc64le-highlighted',
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    if (is_ppc64le()) {
        assert_screen($self->{tag_first_entry_highlighted_hmc_ppc64le}, 60);
    }
    else {
        assert_screen($self->{tag_first_entry_highlighted}, 60);
    }
}

sub edit_current_entry { shift->{grub_menu_base}->edit_current_entry() }
sub select_first_entry { shift->{grub_menu_base}->select_first_entry() }
sub cmd { shift->{grub_menu_base}->cmd() }

1;
