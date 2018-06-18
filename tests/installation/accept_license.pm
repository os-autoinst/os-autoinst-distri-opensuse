# Copyright (C) 2017-2018 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Test module is used to accept license during SLE 15 installation
#          Should be improved to be more product specific
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use strict;
use base "y2logsstep";
use testapi;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    my @tags = qw(network-settings-button license-agreement);

    # During upgrade to sle 15, license agreement is shown as soon as possible
    # when we know which product to upgrade:
    # - s390x and aarch64 installation media contain always just one product,
    #   so the license agreement is shown at welcome screen
    # - other architectures contain more products, the license agreement won't
    #   be shown until user chooses which product to upgrade
    push @tags, 'inst-welcome-no-product-list' if is_sle('15+') && get_var('UPGRADE');

    assert_screen \@tags;
    die 'It seems that license agreement is missing, please check!' if match_has_tag('network-settings-button');
    if (match_has_tag('inst-welcome-no-product-list')) {
        return send_key $cmd{next} unless match_has_tag('license-agreement');
    }
    $self->verify_license_has_to_be_accepted;
    $self->verify_translation if get_var('INSTALLER_EXTENDED_TEST');
    send_key $cmd{next};
    # workaround for bsc#1059317, multiple times clicking accept license
    my $count = 5;
    while (check_screen('license-not-accepted', 3) && $count >= 1) {
        record_soft_failure 'bsc#1059317';
        $self->verify_license_has_to_be_accepted;
        send_key $cmd{next};
        $count--;
    }
}

1;
