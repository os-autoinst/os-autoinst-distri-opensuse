# Evolution tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test Case #1503768: Evolution: send and receive email via IMAP
# Maintainer: Qingming Su <qingming.su@suse.com>

use strict;
use base "x11regressiontest";
use testapi;
use utils;

sub run() {
    my ($self) = @_;
    $self->setup_mail_account('imap', "internal_account_A");
    my $account      = 'internal_account_A';
    my $mail_subject = $self->evolution_send_message($account);
    $self->check_new_mail_evolution($mail_subject, $account, "imap");

    # Exit
    send_key "ctrl-q";
    wait_idle;
}

1;
# vim: set sw=4 et:
