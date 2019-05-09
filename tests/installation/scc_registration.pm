# Copyright (C) 2014-2016 SUSE LLC
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

# Summary: Do the registration against SCC or skip it
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "y2logsstep";

use testapi;
use utils 'assert_screen_with_soft_timeout';
use version_utils 'is_sle';
use registration qw(skip_registration assert_registration_screen_present fill_in_registration_data verify_scc investigate_log_empty_license);

sub run {
    return record_info('Skip reg.', 'SCC registration is not required in media based upgrade since SLE15') if (is_sle('15+') && get_var('MEDIA_UPGRADE'));
    if (check_var('SCC_REGISTER', 'installation') || (check_var('REGISTER', 'installation'))) {
        record_info('SCC reg.', 'SCC registration');
        assert_registration_screen_present();
        fill_in_registration_data();
    }
    else {
        return if check_var('SLE_PRODUCT', 'leanos');
        record_info('Skip reg.', 'Skip registration');
        assert_screen_with_soft_timeout(
            [qw(scc-registration yast2-windowborder-corner)],
            timeout      => 300,
            soft_timeout => 100,
            bugref       => 'bsc#1028774'
        );
        if (match_has_tag('yast2-windowborder-corner')) {
            if (check_var("INSTALLER_NO_SELF_UPDATE", 1)) {
                die "installer should not self-update, therefore window should not have respawned, file bug and replace this line with a soft-fail";
            }
            elsif (check_var('INSTALLER_SELF_UPDATE', 1)) {
                ensure_fullscreen(tag => 'yast2-windowborder-corner');
            }
            else {
                die "so far this should only be reached on s390x which we test only on SLE which has self-update disabled " .
                  "since SLE 12 SP2 GM so we should not reach here unless this is a new version of SLE which has the self-update enabled by default";
            }
            assert_screen_with_soft_timeout(
                'scc-registration',
                timeout      => 300,
                soft_timeout => 100,
                bugref       => 'bsc#1028774'
            );
        }
        skip_registration();
    }
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    verify_scc();
    investigate_log_empty_license();
}

1;
