# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: VNC connection to SUT (the 'sut' console) is terminated via svirt backend on XEN and s390x
# and it is required to re-connect *after* the restart, otherwise the job end up with stalled
# VNC connection.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use power_action_utils qw(prepare_system_shutdown assert_shutdown_and_restore_system);

sub run {
    prepare_system_shutdown;
    assert_shutdown_and_restore_system('reboot', 180);
}

1;
