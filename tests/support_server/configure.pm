# Copyright 2015-2018 SUSE Linux GmbH
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: configure support server repos during image building
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base 'consoletest';
use testapi;
use utils;
use y2_module_basetest;
use version_utils qw(is_opensuse check_os_release);

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
    my @packages = qw(apache2 tftp dhcp-server bind xrdp);
    my $lio_pkg = check_os_release('12', 'VERSION_ID')
      ? 'targetcli' : 'python3-targetcli-fb';
    push(@packages, $lio_pkg);
    zypper_call("in " . join(" ", @packages));
}

sub _turnoff_gnome_screensaver_and_suspend {
    assert_script_run "gsettings set org.gnome.desktop.session idle-delay 0";
    assert_script_run "gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'";
}

sub run {
    my ($self) = shift;
    _remove_installation_media_and_add_network_repos;
    # We use create_hdd
    if (!check_var('SUPPORT_SERVER_GENERATOR', 1)) {
        _install_packages;
        $self->use_wicked_network_manager if is_network_manager_default;
        _turnoff_gnome_screensaver_and_suspend if check_var('DESKTOP', 'gnome');
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
