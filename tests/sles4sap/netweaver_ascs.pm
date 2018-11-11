# SUSE's SLES4SAP openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Checks NetWeaver's ASCS installation as performed by sles4sap/netweaver_ascs_install
# Requires: sles4sap/netweaver_ascs_install, ENV variable SAPADM
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "sles4sap";
use testapi;
use strict;
use utils 'ensure_serialdev_permissions';

sub run {
    my ($self) = @_;
    $self->setup();
    $self->test_common_sap();
}

1;
