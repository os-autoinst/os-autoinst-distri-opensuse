# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;

sub set_scc_proxy_url() {
    if (my $u = get_var('SCC_PROXY_URL')) {
        type_string "echo 'url: $u' > /etc/SUSEConnect\n";
    }
    save_screenshot;
}

sub check_or_install_packages() {
    if (get_var("FULL_UPDATE")) {
        # if system is fully updated, all necessary packages for online migration should be installed
        # check if the packages was installed along with update
        my $output = script_output "rpm -qa yast2-migration zypper-migration-plugin rollback-helper";
        if ($output !~ /yast2-migration.*?zypper-migration-plugin.*?rollback-helper/s) {
            die "migration packages was not installed along with system update";
        }
    }
    else {
        # install necessary packages for online migration if system is not updated
        # also update snapper to ensure rollback service work properly after migration
        assert_script_run "zypper -n in yast2-migration zypper-migration-plugin rollback-helper snapper", 190;
    }
}

sub run() {
    my $self = shift;
    select_console 'root-console';

    check_or_install_packages;

    # set scc proxy url here to perform online migration via scc proxy
    set_scc_proxy_url;
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
