# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ndctl
# Summary: install ndctl. Destroy and configure NVDIMM namespaces
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';

sub run {
    return unless get_var('NVDIMM');
    select_serial_terminal;
    zypper_call('in ndctl');
    assert_script_run 'ndctl destroy-namespace --force all';
    my $total = get_var('NVDIMM_NAMESPACES_TOTAL', 2);
    foreach my $i (0 .. ($total - 1)) {
        my $device = script_output 'ndctl create-namespace --force --mode=fsdax';
        ($device) = $device =~ /\"blockdev\":\"(pmem\d+)\"/;
        assert_script_run "test -b /dev/$device";
        assert_script_run "wipefs -a /dev/$device";
    }
    assert_script_run 'ndctl list';
    assert_script_run 'ndctl list -H -N -D -F > /tmp/ndctl-list 2>&1';
    upload_logs('/tmp/ndctl-list', failok => 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
