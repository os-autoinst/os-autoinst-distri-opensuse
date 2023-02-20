# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Module allows validation of generic configuration files.
# Test data should be defined in the following format:
#  configuration_files:
#    - path: /etc/hosts
#      entries:
#        - 'new.entry.de\t10.226.154.19 h999uz'
#    - path: /etc/chrony.d/pool.conf
#      entries:
#        - pool ntp.suse.de iburst
# See lib/cfg_files_utils.pm
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_module_consoletest';
use strict;
use warnings;

use cfg_files_utils 'validate_cfg_file';
use scheduler;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    validate_cfg_file(get_test_suite_data()->{config_files});
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook;
    # Upload all configurations files which were validated
    upload_logs for (@{get_test_suite_data()->{config_files}});
}

1;
