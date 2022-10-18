# SUSE's openQA tests
#
# Copyright 2017-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Register systemd services for SAP NetWeaver and check for success
# Maintainer: QE-SAP <qe-sap@suse.de>

use base "sles4sap";
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use hacluster;
use strict;
use warnings;
use utils;

sub run {
    my ($self) = @_;
    my $instance_type = get_required_var('INSTANCE_TYPE');
    my $instance_id = get_required_var('INSTANCE_ID');
    my $sid = get_required_var('INSTANCE_SID');
    my $hostname = get_var('INSTANCE_ALIAS', '$(hostname)');
    my $timeout = bmwqemu::scale_timeout(900);    # Time out for NetWeaver's sources related commands
    my $sap_dir = "/usr/sap/$sid";

    select_serial_terminal;

    validate_script_output('cat /usr/sap/sapservices', qr/sapstartsrv/, title => 'sapstartsrv');
    validate_script_output('systemctl list-unit-files | grep -i sap', sub { /^(?!SAP..._\d\d.service)/ }, title => 'NO systemd'); # there must be _no_ SAP*.service
    assert_script_run "LD_LIBRARY_PATH=$sap_dir/${instance_type}${instance_id}/exe:\$LD_LIBRARY_PATH;export LD_LIBRARY_PATH;$sap_dir/${instance_type}${instance_id}/exe/sapstartsrv pf=$sap_dir/SYS/profile/${sid}_${instance_type}${instance_id}_${hostname} -reg";
    validate_script_output('cat /usr/sap/sapservices', qr/systemctl/, title => 'systemctl');
    validate_script_output('systemctl list-unit-files | grep -i sap', sub { /SAP..._\d\d.service/ }, title => 'USE systemd'); # SAP*.service _must_ be there now
}

1;
