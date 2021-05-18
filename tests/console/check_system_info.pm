# Copyright (C) 2019 SUSE LLC
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
#
# Package: SUSEConnect
# Summary: Verify milestone version and display some info.
# Check repos info
# Maintainer: Alynx Zhou <alynx.zhou@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use registration;
use List::MoreUtils 'uniq';

sub run {
    select_console('root-console');
    assert_script_run('setterm -blank 0') unless (check_var('ARCH', 's390x'));

    if (!get_var('MILESTONE_VERSION')) {
        assert_script_run('cat /etc/issue');
    } else {
        my $milestone_version = get_var('MILESTONE_VERSION');
        assert_script_run("grep -w $milestone_version /etc/issue");
    }

    script_run('zypper lr | tee /tmp/zypperlr.txt');

    my $myaddons = get_var('SCC_ADDONS', "");
    $myaddons .= ",base,serverapp"                                  if (is_sle('15+')                                   && check_var('SLE_PRODUCT', 'sles'));
    $myaddons .= ",base,desktop,we,python2"                         if (is_sle('15+')                                   && check_var('SLE_PRODUCT', 'sled'));
    $myaddons .= ",base,serverapp,desktop,dev,lgm,python2,wsm"      if (is_sle('<15', get_var('ORIGIN_SYSTEM_VERSION')) && is_sle('15+'));
    $myaddons .= ",python2"                                         if (is_sle('=15', get_var('ORIGIN_SYSTEM_VERSION')) && is_sle('15+'));
    $myaddons .= ",base,serverapp,desktop,dev,lgm,python2,wsm,phub" if (is_leap_migration);

    # After upgrade, system doesn't include ltss extension
    $myaddons =~ s/ltss,?//g;
    # For hpc, system doesn't include legacy module
    $myaddons =~ s/lgm,?//g if (get_var("SCC_ADDONS", "") =~ /hpcm/);
    my @addons        = grep { $_ =~ /\w/ } split(/,/, $myaddons);
    my @unique_addons = uniq @addons;
    foreach my $addon (@unique_addons) {
        my $name = get_addon_fullname($addon);
        record_info("$addon module fullname: ", $name);
        $name = "sle-product-we"      if (($name =~ /sle-we/)      && !get_var("MEDIA_UPGRADE"));
        $name = "SLE-Module-DevTools" if (($name =~ /development/) && !get_var("MEDIA_UPGRADE"));
        my $out = script_output("zypper lr | grep -i $name", 200, proceed_on_failure => 1);
        die "zypper lr command output does not include $name" if ($out eq '');
    }
}

sub post_fail_hook {
    my $self = shift;
    upload_logs '/tmp/zypperlr.txt';
    $self->SUPER::post_fail_hook;
}

1;
