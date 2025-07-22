# Copyright 2015-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: systemd-sysvinit
# Summary: Reboot for autoyast scenarios
# - Call power_action reboot, with options "keepconsole => 1" and "textmode =>
# 1"
# Maintainer: Pavel Sladek <psladek@suse.cz>

use base 'basetest';
use testapi;
use power_action_utils 'power_action';

sub run {
    # We are already in console, so reboot from it and do not switch to x11 or root console
    # Note, on s390x with SLE15 VNC is not running even if enabled in the profile
    power_action('reboot', textmode => 1, keepconsole => 1);
}

1;

