# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rpcbind nfs-kernel-server
# Summary: rpcbind test
# - Install rpcbind and nfs-kernel-server and check
# - Export a mount point on /etc/exports and create a test file inside
# - Enable and start rpcbind, nfs-server and check
# - Mount nfs point, check test file
# - Umount nfs
# Maintainer: Jozef Pupava <jpupava@suse.com>

use warnings;
use base 'consoletest';
use strict;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(systemctl zypper_call);
use services::rpcbind;

sub run {
    my ($self) = @_;
    select_serial_terminal();
    services::rpcbind::install_service();
    services::rpcbind::check_install();
    services::rpcbind::config_service();
    services::rpcbind::enable_service();
    services::rpcbind::check_enabled();
    services::rpcbind::start_service();
    services::rpcbind::check_service();
    services::rpcbind::check_function();
}

sub post_run_hook {
    services::rpcbind::stop_service();
}

1;
