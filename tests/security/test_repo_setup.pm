# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup online repos or dvd images for further testing
# Maintainer: QE Security <none@suse.de>
# Tags: poo#52808

use strict;
use warnings;
use base "consoletest";
use testapi;
use Utils::Architectures;
use utils;
use version_utils "is_sle";
use registration qw(cleanup_registration register_product add_suseconnect_product);
use Utils::Backends 'is_pvm';

sub repo_cleanup {
    cleanup_registration;
    assert_script_run "rm -f /etc/zypp/repos.d/*.repo";
    # Make sure all repositories are cleaned
    validate_script_output("zypper lr || true", sub { m/No repo/ });
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

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

            # For FIPS tests on powerVM, we may need add desktop repo to enable x11 access
            add_suseconnect_product('sle-module-desktop-applications') if (get_var("FIPS_ENABLED") && is_pvm);

            # WE addon registration (according to the conditions)
            if (get_var("SECTEST_REQUIRE_WE") && is_x86_64) {
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

    if (!is_s390x) {
        # Add all available ISO images can be found
        my $sr_out = script_output("cd /dev && ls -1 sr* && cd", proceed_on_failure => 1);
        if ($sr_out =~ /No such file/) {
            die "DVD images not found!" if (!is_x86_64);
        } else {
            foreach my $sr (split("\n", $sr_out)) {
                zypper_call("ar dvd:///?devices=/dev/$sr $sr");
            }
        }
    } else {
        # DVD is usually not available for s390x, so add repository instead
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
