# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
use utils qw(systemctl zypper_call);
use services::rpcbind;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal();
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
