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
    my $pscmd = $self->set_ps_cmd('ASCS');

    select_console 'root-console';

    # The SAP Admin was set in sles4sap/netweaver_ascs_install
    $self->set_sap_info(get_required_var('SAPADM'));
    $self->become_sapadm;

    $self->test_version_info;
    $self->test_instance_properties;
    $self->test_stop;

    script_run "$pscmd | wc -l ; $pscmd";
    save_screenshot;

    $self->test_start_service;
    $self->test_start_instance;

    # Rollback changes to $testapi::serialdev and close the window
    type_string "exit\n";
    ensure_serialdev_permissions;
}

1;
