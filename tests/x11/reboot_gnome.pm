# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Reboot GNOME with or without authentication and ensure proper boot
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub run() {
    my ($self) = @_;
    if (check_var('DISTRI', 'sle')) {
        # Increase logging level for bsc#1000599
        select_console("root-console");
        # Long string, hence type slowly
        type_string_slow "sed -i 's|\\(/usr/lib/gnome-settings-daemon-3.0/gnome-settings-daemon\\)|\\1 --debug|g'"
          . " /usr/lib/gnome-settings-daemon-3.0/gnome-settings-daemon-localeexec\n";
        type_string_slow "sed -i 's|\\(/usr/lib/gnome-settings-daemon-3.0/gnome-settings-daemon-localeexec\\)|systemd-cat \\1|g'"
          . " /etc/xdg/autostart/gnome-settings-daemon.desktop\n";
        # Restart gnome to apply changes to services
        assert_script_run "systemctl restart xdm";
        # After restarting gnome need to login again
        handle_login;
    }
    # 'keepconsole => 1' is workaround for bsc#1044072
    power_action('reboot', keepconsole => 1);

    # on s390x svirt encryption unlock has to be done before this wait_boot
    workaround_type_encrypted_passphrase if get_var('S390_ZKVM');
    $self->wait_boot(bootloader_time => 300);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    $self->export_logs;
}

sub test_flags() {
    return {milestone => 1};
}

1;

# vim: set sw=4 et:
