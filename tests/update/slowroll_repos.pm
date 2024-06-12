# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Add slowroll repos in the system
# Maintainer: Yiannis Bonatakis <ybonatakis@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    assert_script_run "rm /etc/zypp/repos.d/*";
    assert_script_run "zypper -n --gpg-auto-import-keys ar --refresh http://cdn.opensuse.org/slowroll/repo/oss/ base-oss";
    assert_script_run "zypper -n --gpg-auto-import-keys ar --refresh http://cdn.opensuse.org/slowroll/repo/non-oss/ base-non-oss";
    assert_script_run "zypper -n --gpg-auto-import-keys ar --refresh -p 80 http://cdn.opensuse.org/update/slowroll/repo/oss/ update";

    assert_script_run "zypper -n --gpg-auto-import-keys dup";
}

sub test_flags {
    return {fatal => 1};
}

1;
