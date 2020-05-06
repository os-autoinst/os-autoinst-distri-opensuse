# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: console test pre setup, performing actions required to run tests
# which are supposed to be reverted e.g. stoping and disabling packagekit and so on
# Permanent changes are now executed in system_prepare module
# - Save screenshot
# - Disable/stop serial-getty service
# - Disable mail notifications system-wide
# - Disable/stop packagekit service
# - Enable pipefail
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use testapi;
use utils qw(check_console_font disable_serial_getty);
use Utils::Backends qw(has_ttys use_ssh_serial_console);
use Utils::Systemd 'disable_and_stop_service';
use strict;
use warnings;

sub run {
    my $self = shift;
    # let's see how it looks at the beginning
    save_screenshot;
    check_var("BACKEND", "ipmi") ? use_ssh_serial_console : select_console 'root-console';

    # Stop serial-getty on serial console to avoid serial output pollution with login prompt
    disable_serial_getty;
    # init
    check_console_font if has_ttys();

    # Prevent mail notification messages to show up in shell and interfere with running console tests
    script_run 'echo "unset MAILCHECK" >> /etc/bash.bashrc.local';
    script_run 'echo "set -o pipefail" >> /etc/bash.bashrc.local';
    script_run '. /etc/bash.bashrc.local';
    disable_and_stop_service('packagekit.service', mask_service => 1);

    $self->clear_and_verify_console;
}

sub post_fail_hook {
    my $self = shift;
    select_console('log-console');
    $self->export_logs();
    $self->export_logs_locale();
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
