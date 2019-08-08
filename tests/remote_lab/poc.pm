# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Proof-of-concept of connecting to a remote lab hardware for test
#   execution
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: https://progress.opensuse.org/issues/49901

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;


sub run {
    my ($self) = @_;
    select_console 'root-console';
    assert_script_run('hostname | grep -q suse1', fail_message => 'It seems we are not on the right remote SUT host');
    assert_script_run('supportconfig',            600);
    assert_script_run('mv $(ls -t /var/log/*.tbz | head -1) supportconfig.tbz');
    upload_logs('supportconfig.tbz');
}

1;
