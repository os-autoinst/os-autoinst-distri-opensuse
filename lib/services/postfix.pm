# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Package for postfix service tests
#
# Maintainer: Alynx Zhou <alynx.zhou@suse.com>

package services::postfix;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;

sub install_service {
    # mailx is used to send mail
    zypper_call('in postfix mailx');
}

sub enable_service {
    systemctl('enable postfix');
}

sub start_service {
    systemctl('start postfix');
}

# check service is running and enabled
sub check_service {
    systemctl('is-enabled postfix');
    systemctl('is-active postfix');
}

# check postfix function
sub check_function {
    # Clear mailbox
    type_string("rm /var/spool/mail/$testapi::username\n");
    # Send testing mail
    assert_script_run("echo 'Mail body' | mailx -v -s 'openQA Testing' $testapi::username\@localhost");
    # Flush mail queue to ensure mail has been sent
    assert_script_run("postfix flush");
    # Verify mail received
    assert_script_run("grep 'openQA Testing' /var/spool/mail/$testapi::username");
}

# check postfix service before and after migration
# stage is 'before' or 'after' system migration.
sub full_postfix_check {
    my ($stage) = @_;
    $stage //= '';
    if ($stage eq 'before') {
        install_service();
        enable_service();
        start_service();
    }
    check_service();
    check_function();
}

1;

