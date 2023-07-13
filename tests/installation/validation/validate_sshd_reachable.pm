# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate the sshd is running *and* that port 22 is opened,as
# admins may want to connect with ssh right after an ssh installation.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use services::sshd;
use testapi "select_console";

sub run {
    select_console 'root-console';
    services::sshd::check_sshd_service();
    services::sshd::check_sshd_port();
}

1;
