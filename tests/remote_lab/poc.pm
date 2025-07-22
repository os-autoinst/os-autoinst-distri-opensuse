# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Proof-of-concept of connecting to a remote lab hardware for test
#   execution
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: https://progress.opensuse.org/issues/49901

use base 'opensusebasetest';
use testapi;
use upload_system_log 'upload_supportconfig_log';

sub run {
    my ($self) = @_;
    select_console 'root-console';
    assert_script_run('hostname | grep -q suse1', fail_message => 'It seems we are not on the right remote SUT host');
    upload_supportconfig_log();
}

1;
