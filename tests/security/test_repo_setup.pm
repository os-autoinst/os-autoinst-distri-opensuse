# Copyright © 2019 SUSE LLC
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
# Summary: Setup online repos or dvd images for further testing
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Tags: poo#52808

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;
use version_utils "is_sle";
use registration qw(cleanup_registration register_product add_suseconnect_product);

sub repo_cleanup {
    cleanup_registration;
    assert_script_run "rm -f /etc/zypp/repos.d/*.repo";
    # Make sure all repositories are cleaned
    validate_script_output("zypper lr || true", sub { m/No repo/ });
}

sub run {
    my ($self) = @_;
    select_console 'root-console';

    # Note: Check the ticket in p.o.o for detailed descriptions of the
    #       repository setup logic.

    if (!get_var('SECTEST_DVD_SRC') && is_sle) {
        my $sc_out = script_output("SUSEConnect --status-text", proceed_on_failure => 1);

        record_info "Not Registered", "System is not registered, add DVD image as repositories." if ($sc_out =~ /Not Registered/);

        # If the the network is not available to check if it is registered.
        # Then proceed following steps to add DVD repo.
        record_info "Network Error", "SUSEConnect error: SocketError" if ($sc_out =~ /SocketError/);

        if ($sc_out =~ /Status.*ACTIVE/) {
            set_var('SCC_REGCODE', ($sc_out =~ /Regcode: (.*)/)) if (!get_var("SCC_REGCODE"));
            die "SCC_REGCODE not specified" if (!get_var('SCC_REGCODE'));
            repo_cleanup;
            # Base system registration
            register_product;

            # WE addon registration (according to the conditions)
            if (get_var("SECTEST_REQUIRE_WE") && check_var("ARCH", "x86_64")) {
                # Register Desktop module as a dependency
                add_suseconnect_product('sle-module-desktop-applications');

                # Register WE with workaround if NVIDIA repository is (usually) not ready
                my ($pd_no) = $sc_out =~ /\(SLES\/(.*)\/x86_64\)/;
                die "WE registration failed" if
                  (script_output("SUSEConnect -p sle-we/$pd_no/x86_64 -r " . get_required_var("SCC_REGCODE_WE"),
                        proceed_on_failure => 1, timeout => 180)
                    !~ m/NVIDIA-Driver.*not found|Successfully registered/);
            }

            zypper_call("--gpg-auto-import-keys refresh");
            return;
        }

        # Invalid system credentials, it is possible has been de-registered on
        # SCC. Perform re-registration, SCC_REGCODE is needed, or it will
        # process following steps to add ISO image
        if ($sc_out =~ /Invalid system credentials/) {
            record_info "SCC Invalid", "Invalid system credentials, it is possible has been de-registered on SCC.";
            my $regcode = get_var("SCC_REGCODE");
            if ($regcode) {
                repo_cleanup;
                # Only base system will be registered here
                assert_script_run "SUSEConnect -r $regcode";
                return;
            }
        }
    }

    repo_cleanup;

    # Add all available ISO images can be found
    my $sr_out = script_output("cd /dev && ls -1 sr* && cd", proceed_on_failure => 1);
    die "DVD images not found!" if ($sr_out =~ /No such file/);

    foreach my $sr (split("\n", $sr_out)) {
        zypper_call("ar dvd:///?devices=/dev/$sr $sr");
    }

    # It is usually no DVD available for s390x testing, so we add repository
    if (check_var('ARCH', 's390x')) {
        my $mirror_src = get_required_var('MIRROR_HTTP');
        zypper_call("ar $mirror_src MIRROR_HTTP_SRC");

        if (is_sle('>=15')) {
            my $urlprefix = get_required_var('MIRROR_PREFIX');
            foreach my $n ('SLE_PRODUCT_SLES', 'SLE_MODULE_BASESYSTEM',
                'SLE_MODULE_SERVER_APPLICATIONS', 'SLE_MODULE_DESKTOP_APPLICATIONS') {
                next unless get_var("REPO_$n");
                my $repourl = $urlprefix . "/" . get_var("REPO_$n");
                zypper_call("ar $repourl $n");
            }
        }
    }

    zypper_call("--gpg-auto-import-keys ref");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
