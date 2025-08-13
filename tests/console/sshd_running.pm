# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Ensure the ssh daemon is running
# - Check if sshd is started
# - Check if sshd is running
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use testapi;
use utils;
use services::sshd;

sub run {
    services::sshd::check_sshd_service();
}

1;
