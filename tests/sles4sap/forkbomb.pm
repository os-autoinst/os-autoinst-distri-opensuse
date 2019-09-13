# SUSE's SLES4SAP openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Performed a "forkbomb" test on HANA
# Requires: sles4sap/wizard_hana_install, ENV variables INSTANCE_SID
# Maintainer: Ricardo Branco <rbranco@suse.de>

use base "sles4sap";
use testapi;
use strict;
use warnings;

sub run {
    my ($self) = @_;

    # NOTE: Do not call this function on the qemu backend
    # The first forkbomb can create 3 times as many processes as the second due to unknown bug
    return if check_var('BACKEND', 'qemu');

    $self->select_serial_terminal;

    # The SAP Admin was set in sles4sap/wizard_hana_install
    my $sid         = get_required_var('INSTANCE_SID');
    my $instance_id = get_required_var('INSTANCE_ID');
    my $sapadm      = $self->set_sap_info($sid, $instance_id);
    $self->test_forkbomb;
}

1;
