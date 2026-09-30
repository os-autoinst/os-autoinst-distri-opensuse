## Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Wait support server to be ready for installation test on multi-machine.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'installbasetest';

use testapi;
use lockapi 'mutex_wait';

sub run {
    send_key 'e' if (check_screen('grub-menu-first-entry-highlighted', 120));

    mutex_wait 'support_server_ready';

    send_key 'esc';
}

1;
