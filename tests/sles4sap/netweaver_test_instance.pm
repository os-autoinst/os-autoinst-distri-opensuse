# SUSE's SLES4SAP openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Checks NetWeaver installation as performed by sles4sap/netweaver_install
# Requires: sles4sap/netweaver_install, ENV variables INSTANCE_SID, INSTANCE_TYPE and INSTANCE_ID
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "sles4sap";
use testapi;
use strict;
use warnings;
use version_utils 'is_upgrade';

sub run {
    my ($self) = @_;
    my $pscmd = $self->set_ps_cmd(get_required_var('INSTANCE_TYPE'));

    $self->select_serial_terminal;

    # First, upload the installation logs
    # NOTE: done here because there are multiple installation paths
    $self->upload_nw_install_log;

    # On upgrade scenarios, hostname and IP address could have changed from the original
    # installation of NetWeaver. This ensures the current hostname can be resolved
    if (is_upgrade) {
        assert_script_run 'sed -i /$(hostname)/d /etc/hosts';
        $self->add_hostname_to_hosts;
    }

    # The SAP Admin was set in sles4sap/netweaver_install
    $self->set_sap_info(get_required_var('INSTANCE_SID'), get_required_var('INSTANCE_ID'));
    # Don't test pids_max on migration
    $self->test_pids_max unless (get_var('UPGRADE') or get_var('ONLINE_MIGRATION'));
    $self->user_change;

    # Do the stop/start tests
    $self->test_version_info;
    $self->test_instance_properties;
    $self->test_stop;
    $self->test_start;

    # Disconnect SAP account
    $self->reset_user_change;
}

1;
