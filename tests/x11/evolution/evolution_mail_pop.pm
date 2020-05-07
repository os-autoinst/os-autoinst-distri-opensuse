# Evolution tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test Case #1503919 - Evolution: send and receive email via POP
# - Setup pop account on evolution with credentials from internal_account_A
# - Send an email to internal_account_A with subject as current date and random
#   string
# - Check for test email and check result
# - Save a screenshot
# - Exit evolution
# Maintainer: Zhaocong Jia <zcjia@suse.com>

use strict;
use warnings;
use base "x11test";
use testapi;
use utils;

sub run {
    my $self = shift;
    # Select correct account to use with multimachine.
    my $account  = "internal_account";
    my $hostname = get_var('HOSTNAME');
    if ($hostname eq 'client') {
        $account = "internal_account_C";
    }
    else {
        $account = "internal_account_A";
    }
    $self->setup_pop($account);

    my $mail_subject = $self->evolution_send_message($account);
    $self->check_new_mail_evolution($mail_subject, $account, "pop");

    # Exit
    send_key "ctrl-q";
}

1;
