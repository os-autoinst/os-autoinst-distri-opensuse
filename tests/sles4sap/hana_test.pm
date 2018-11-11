# SUSE's SLES4SAP openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Checks HANA installation as performed by sles4sap/hana (sles4sap/hana_test)
# Requires: sles4sap/hana, ENV variable SAPADM
# Maintainer: Ricardo Branco <rbranco@suse.de>

use base "sles4sap";
use testapi;
use strict;
use utils 'ensure_serialdev_permissions';

sub run {
    my ($self) = @_;
    $self->setup();
    my $password = get_required_var('PASSWORD');
    my $output   = script_output "hdbsql -j -d NDB -u SYSTEM -n localhost:30015 -p $password 'SELECT * FROM DUMMY'";
    die "hdbsql: failed to query the dummy table\n\n$output" unless ($output =~ /1 row selected/);
    $self->test_common_sap();
}

1;
