# SUSE's openQA tests
#
# Copyright © 2012-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: k3s
# Summary: Smoke test for k3s CLI
#          This module assumes kubectl and k3s is already installed.
# Maintainer: qa-c@suse.de

use base "consoletest";
use testapi;
use version_utils 'is_sle_micro';
use strict;
use warnings;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    record_info('kubectl', script_output('kubectl'));
    record_info('k3s',     script_output('k3s'));
    record_info('version', script_output('k3s -v'));
    assert_script_run('k3s server --help');
    assert_script_run('k3s server --help');
    assert_script_run('k3s agent --help');
    assert_script_run('k3s kubectl --help');
    assert_script_run('k3s crictl --help');
    assert_script_run('k3s etcd-snapshot --help');
}

1;
