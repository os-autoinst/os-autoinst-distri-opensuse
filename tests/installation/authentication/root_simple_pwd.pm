# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Enter simple password for root in YaST interactive
# installation and accept corresponding warning pop-up
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use Test::Assert ':all';

sub run {
    my $auth_for_root = $testapi::distri->get_authentication_for_root();
    my $warning_text  = 'The password is too simple:\nit is based on a dictionary word.';

    $auth_for_root->set_password($testapi::password);
    $testapi::distri->get_navigation()->proceed_next_screen();

    my $warning = $auth_for_root->get_weak_password_warning();
    die 'Weak password warning was not shown' unless $warning->is_shown();
    assert_matches(qr/$warning_text/, $warning->text(),
        'Wrong warning popup text when introducing a weak password');
    $warning->press_yes();
}

1;
