# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: uuidd util-linux
# Summary: Test uuidd daemon and UUID generation
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use utils 'systemctl';

sub run {
    select_serial_terminal;

    # Install uuidd daemon package using package_utils
    install_package('uuidd', trup_apply => 1);

    # Start and check uuidd service is active
    systemctl('start uuidd.service');
    systemctl('is-active uuidd.service');

    # Validate UUID generation via uuidd and uuidgen
    validate_script_output('uuidd -r', qr/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);
    validate_script_output('uuidd -t', qr/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);
    validate_script_output('uuidgen --random', qr/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);
    validate_script_output('uuidgen --time', qr/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);
}


sub test_flags {
    return {fatal => 1};
}

1;

