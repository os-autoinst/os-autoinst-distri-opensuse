# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Checks for embargoed updates on IBSM
# Maintainer: QE-SAP <qe-sap@suse.de>

use strict;
use warnings;
use base 'sles4sap_publiccloud_basetest';
use publiccloud::utils "validate_repo";
use testapi;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run() {
    my ($self, $run_args) = @_;
    $self->import_context($run_args);
    my $instance = $run_args->{my_instance};

    my @repos = split(/,/, get_var('INCIDENT_REPO'));
    my $count = 0;

    while (defined(my $maintrepo = shift @repos)) {
        next if $maintrepo =~ /^\s*$/;
        # validate_repo returns 0 if an embargoed update is found, so it's reversed to enter the loop
        if (!validate_repo($maintrepo)) {
            $instance->run_ssh_command(cmd => "sudo zypper --no-gpg-checks ar -f -n TEST_$count $maintrepo TEST_$count",
                username => 'cloudadmin');
            my $rc = $instance->run_ssh_command(cmd => "sudo zypper -n ref TEST_$count", username => 'cloudadmin', timeout => 1500, rc_only => 1);
            die "EMBARGOED REPOSITORY IN IBSM: $maintrepo" if !$rc;
            $count++;
        }
    }
    record_info('NO EMBARGOED', 'No embargoed updates found on the IBSMirror.');
}

1;
