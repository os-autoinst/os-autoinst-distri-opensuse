# SUSE's SLES4SAP openQA tests
#
# Copyright 2018-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: BONE installation validation
# Requires: sles4sap/wizard_hana_install, ENV variables INSTANCE_SID
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap';
use strict;
use warnings;
use testapi;
use utils qw(file_content_replace);
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    # validation variables
    my $val_cfg = "b1.settings";
    my $hostname = script_output 'hostname';
    my $local_url = "http://10.100.103.247:8000/";
    my $sid = get_required_var('INSTANCE_SID');
    my $instid = get_required_var('INSTANCE_ID');
    my $bone_parser = "b1_log.sh";

    # download template file
    assert_script_run "curl -f -v " . $local_url . "$val_cfg -o /tmp/$val_cfg";

    # replace variables in config file
    file_content_replace("/tmp/$val_cfg", '%SERVER%' => $hostname, '%INSTANCE%' => $instid, '%TENANT_DB%' => $sid, '%PASSWORD%' => $sles4sap::instance_password);

    # run the validation
    assert_script_run "/usr/sap/SAPBusinessOne/setup -va silent -f /tmp/$val_cfg | tee /tmp/bone-results.txt";

    # check results
    my $bone_results_file = script_output('grep var /tmp/bone-results.txt | cut -d ":" -f 2');
    assert_script_run "curl -f -v " . $local_url . "$bone_parser -o /tmp/$bone_parser";
    assert_script_run "chmod +x /tmp/$bone_parser";
    assert_script_run "/tmp/$bone_parser $bone_results_file";
    upload_logs($bone_results_file);
}

1;
