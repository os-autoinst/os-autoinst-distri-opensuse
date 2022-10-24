# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Mount an iso file using autofs/automount
# - If SLE15+, installs autofs mkisofs
# - Creates a temporary directory, /mnt/test_autofs_local
# - Inside temporary directory, creates a README file, with 4024 bytes.
# - Creates a /tmp/test-iso.iso with contents of temporary directory using
# mkisofs
# - Checks iso created using "ls -lh"
# - Calls check_autofs_service (start/stop/restart/status of autofs)
# - Calls setup_autofs_server (configure autofs config files)
# - Restart autofs
# - Runs ls /mnt/test_autofs_local/iso
# - Checks output of mount | grep -e /tmp/test-iso.iso contains
# "/tmp/test-iso.iso", otherwise, abort
# Maintainer: Antonio Caristia <acaristia@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use autofs_utils;

sub run {
    select_serial_terminal;
    autofs_utils::configure_service('function');
    autofs_utils::check_function();
    autofs_utils::do_cleanup();
}

1;
