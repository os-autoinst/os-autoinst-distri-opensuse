# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Add default user with simple password in YaST interactive
# installation and accept corresponding warning pop-up
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use Test::Assert ':all';

sub run {
    my $local_user = $testapi::distri->get_local_user();
    my $warning_text = 'The password is too simple:\nit is based on a dictionary word.';

    $local_user->create_user(full_name => $testapi::realname, password => $testapi::password);
    $testapi::distri->get_navigation()->proceed_next_screen();

    my $warning = $local_user->get_weak_password_warning();
    die 'Weak password warning was not shown' unless $warning->is_shown();
    assert_matches(qr/$warning_text/, $warning->text(),
        'Wrong warning popup text when introducing a weak password');
    $warning->press_yes();
}

1;

