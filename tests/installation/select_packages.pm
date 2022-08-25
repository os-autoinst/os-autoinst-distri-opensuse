# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Select given PACKAGES
#    You can pass
#    PACKAGES=quota-nfs,-samba,-grub2  packages starting with - will be removed
#    some package will block installation, conflict will be resolved passing
#    INSTALLATION_BLOCKED=grub2
#
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use version_utils;

sub run {
    my ($self) = @_;
    my $packages = get_required_var('PACKAGES');
    my $blocker_packages = get_var('INSTALLATION_BLOCKED');
    my $operation;

    $self->go_to_patterns();
    $self->go_to_search_packages();
    for my $package_name (split(/,/, $packages)) {
        if ($package_name =~ /^-/) {
            $operation = 'minus';
            $package_name =~ s/^-//;    # remove minus char first
        }
        else {
            $operation = '+';
        }
        $self->search_package($package_name);
        $self->toggle_package($package_name, $operation);
    }
    $self->back_to_overview_from_packages();

    if (is_sle('<15') && !check_screen('inst-overview-blocked', 0)) {
        record_soft_failure('bsc#1029660 - package removal, different result with same workflow');
        $self->go_to_patterns();
        $self->go_to_search_packages();
        # this will only work for one blocker package: grub2
        $self->search_package('grub2');
        $self->toggle_package('grub2', 'minus');
        wait_screen_change { send_key 'alt-a' };    # accept
        assert_screen('automatic-changes');
        send_key 'alt-o';
        $self->accept3rdparty();
        assert_screen('installation-settings-overview-loaded');
    }

    if ($blocker_packages) {
        # Check that installation is blocked (expected behavior)
        assert_screen 'inst-overview-blocked';
        send_key 'alt-i';
        assert_screen 'startinstall-blocked';
        send_key 'alt-o';
        assert_screen 'inst-overview-blocked';

        $self->go_to_patterns();
        $self->go_to_search_packages();
        for my $package_name (split(/,/, $blocker_packages)) {
            $self->search_package($package_name);
            $self->toggle_package($package_name, '+');
        }
        $self->back_to_overview_from_packages();

        if (check_screen('inst-overview-blocked', 0)) {
            die('Installation looks blocked. Is some blocker package not included in INSTALLATION_BLOCKED?');
        }
    }
}

1;
