# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cups
# Summary: Test basic capabilities of cups
# - check 'cupsd -t' output
# - enable and start cups.service
# - check that cups is active
# - check using lpstat that no destination is present
# - add printers using lpadmin
# - for each printer, submit a print job to the queue, list it and cancel it
# - restart cups and check its status
# - print a file using all prints
# - check cups access log
# - remove all previously added printers
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(systemctl zypper_call);
use Utils::Systemd 'disable_and_stop_service';
use version_utils;
use Utils::Architectures;
use services::cups;

sub run {
    select_serial_terminal unless (is_s390x);

    services::cups::install_service();
    services::cups::config_service();
    services::cups::enable_service();
    services::cups::restart_service();
    services::cups::check_service();
    services::cups::check_function();

    disable_and_stop_service('cups.path') if (script_run('systemctl cat cups.path') == 0);
    disable_and_stop_service('cups.socket') if (script_run('systemctl cat cups.socket') == 0);
    disable_and_stop_service('cups.service');
    validate_script_output '{ systemctl --no-pager status cups.service | cat; } || test $? -eq 3', sub { m/Active:\s*inactive/ };
}

1;
