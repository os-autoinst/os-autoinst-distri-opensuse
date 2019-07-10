# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Simple apache server test
# Maintainer: Oliver Kurz <okurz@suse.de>

package http_srv;
use services::apache;
use strict;
use warnings;
use base 'consoletest';
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'root-console';
    script_run("df -h > /dev/$serialdev", 0);

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
