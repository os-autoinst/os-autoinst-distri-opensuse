# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: apache2
# Summary: Simple apache server test
# - Install apache2
# - Enable apache2 service
# - Start apache2 service
# - Check status of apache2 service
# - Create index.html, connect to apache instance, check page
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use services::apache;
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self) = @_;
    select_serial_terminal();

    services::apache::install_service();
    services::apache::enable_service();
    services::apache::start_service();
    services::apache::check_service();
    services::apache::check_function();
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    select_console('log-console');
    # Log disk usage if test failed, see poo#19834
    script_run("df -h > /dev/$serialdev", 0);
}

1;
