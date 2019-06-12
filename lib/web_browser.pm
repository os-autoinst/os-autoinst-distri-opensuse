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

# Summary: common functions for FIPS web browser tests
# Maintainer: llzhao <llzhao@suse.com>

package web_browser;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';
use registration qw(add_suseconnect_product register_product);

our @EXPORT = qw(
  setup_web_browser_env
  run_web_browser_text_based
);

# Setup test envs: register PackageHub and check FIPS pattern installed
sub setup_web_browser_env {
    my $ret = 0;

    if (is_sle) {
        # Check the register status for reference
        script_run("SUSEConnect --list-extension | grep 'SUSE Package Hub' | grep '(Activated)'");
        $ret = script_run("output=`SUSEConnect -s | grep 'PackageHub'`; echo \${output##*PackageHub} | cut -d ':' -f4 | grep 'Registered'");
        # Workaround: in some cases extensions may be in false "Activated" status,
        # then just re-register it and do not check the return value
        if ($ret ne 0) {
            register_product();
            my $version = get_required_var('VERSION') =~ s/([0-9]+)-SP([0-9]+)/$1.$2/r;
            my $arch    = get_required_var('ARCH');
            script_run("SUSEConnect -d -p PackageHub/$version/$arch", 300);
            script_run("SUSEConnect -p PackageHub/$version/$arch",    300);
        }
    }
    zypper_call("--no-refresh --no-gpg-checks search -it pattern fips") if get_var('FIPS_ENABLED');
}

# Run text based web browser with options
# $browser: The name of text based web browser: w3m/links/lynx
# $options: command line options
sub run_web_browser_text_based {
    my ($browser, $options) = @_;

    my %https_url = (
        google => "https://www.google.com/ncr",
        suse   => "https://www.suse.com/",
        OBS    => "https://build.opensuse.org/",
    );

    for my $p (keys %https_url) {
        type_string "clear\n";
        script_run "$browser $options $https_url{$p}", 0;

        # Send key "o" ("OK" button) in case of any popup
        # Note: key "o" can open "Option Setting Panel" in "w3m"
        if ($browser ne "w3m") {
            send_key "o";
        }

        assert_screen "$browser-connect-$p-webpage";
        send_key "q";
        send_key "y";
    }
}

1;
