# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: ndctl
# Summary: install ndctl. Destroy and configure NVDIMM namespaces
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    my $self = shift;
    return unless get_var('NVDIMM');
    $self->select_serial_terminal;
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
