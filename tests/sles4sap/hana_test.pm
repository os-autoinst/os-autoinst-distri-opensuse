# SUSE's SLES4SAP openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Checks HANA installation as performed by sles4sap/wizard_hana_install
# Requires: sles4sap/wizard_hana_install, ENV variables INSTANCE_SID
# Maintainer: Ricardo Branco <rbranco@suse.de>

use base "sles4sap";
use testapi;
use strict;
use warnings;

sub run {
    my ($self) = @_;
    my $ps_cmd = $self->set_ps_cmd('HDB');

    $self->select_serial_terminal;

    # Check the memory/disk configuration
    assert_script_run 'clear ; free -m';
    assert_script_run 'lvs -ao +devices vg_hana';
    assert_script_run 'df -k | grep vg_hana';
    save_screenshot;

    # The SAP Admin was set in sles4sap/wizard_hana_install
    my $sid         = get_required_var('INSTANCE_SID');
    my $instance_id = get_required_var('INSTANCE_ID');
    my $sapadm      = $self->set_sap_info($sid, $instance_id);
    $self->test_pids_max;
    $self->user_change;

    # Check HDB with a database query
    my $password = get_required_var('PASSWORD');
    my $output   = script_output "hdbsql -j -d $sid -u SYSTEM -n localhost:30015 -p $password 'SELECT * FROM DUMMY'";
    die "hdbsql: failed to query the dummy table\n\n$output" unless ($output =~ /1 row selected/);

    # Do the stop/start tests
    $self->test_version_info;
    $self->test_instance_properties;
    $self->test_stop;
    $self->test_start;

    assert_script_run "HDB info";

    # Disconnect SAP account
    $self->reset_user_change;
}

1;
