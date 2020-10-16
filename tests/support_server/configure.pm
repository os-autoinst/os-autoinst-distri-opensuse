# Copyright (C) 2015-2018 SUSE Linux GmbH
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

# Summary: configure support server repos during image building
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use y2_module_basetest;
use version_utils 'is_opensuse';

sub _remove_installation_media_and_add_network_repos {
    # this is supposed to run during SUPPORTSERVER_GENERATOR
    #
    # remove the installation media
    my $script = "zypper lr\n";
    $script .= "zypper rr 1\n" unless is_opensuse;
    # optionally add network repos
    if (get_var("POOL_REPO")) {
        $script .= "zypper -n --no-gpg-checks ar --refresh '" . get_var("POOL_REPO") . "' pool\n";
    }

    if (get_var("UPDATES_REPO")) {
        $script .= "zypper -n --no-gpg-checks ar --refresh '" . get_var("UPDATES_REPO") . "' updates\n";
    }

    if (get_var("SLENKINS_TESTSUITES_REPO")) {
        $script .= "zypper -n --no-gpg-checks ar --refresh '" . get_var("SLENKINS_TESTSUITES_REPO") . "' slenkins_testsuites\n";
    }

    if (get_var("SLENKINS_REPO")) {
        $script .= "zypper -n --no-gpg-checks ar --refresh '" . get_var("SLENKINS_REPO") . "' slenkins\n";
    }
    $script .= "zypper --gpg-auto-import-keys ref -f\n";
    script_output($script);
}

sub _install_packages {
    my @packages = qw(apache2 tftp dhcp-server bind yast2-iscsi-lio-server xrdp);
    zypper_call("in " . join(" ", @packages));
}

sub _turnoff_gnome_screensaver_and_suspend {
    assert_script_run "gsettings set org.gnome.desktop.session idle-delay 0";
    assert_script_run "gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'";
}
sub _switch_to_wicked_if_require {
    my ($self) = shift;
    return unless is_network_manager_default;
    $self->use_wicked_network_manager;
}
sub run {
    _remove_installation_media_and_add_network_repos;
    # We use create_hdd
    if (!check_var('SUPPORT_SERVER_GENERATOR', 1)) {
        _install_packages;
        _switch_to_wicked_if_require;
        _turnoff_gnome_screensaver_and_suspend if check_var('DESKTOP', 'gnome');
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
