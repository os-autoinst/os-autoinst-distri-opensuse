# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Helper to boot into existing s390x zvm guest
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "installbasetest";

use testapi;
use strict;
use warnings;

use backend::console_proxy;

sub get_to_system {
    my ($ipl_from) = @_;
    my $s3270 = console('x3270');

    $s3270->sequence_3270('ENTER',);
    $s3270->sequence_3270('String("cp i cms")',);
    $s3270->sequence_3270('ENTER',);
    $s3270->sequence_3270('ENTER',);
    $s3270->sequence_3270(qq/String("cp i $ipl_from")/,);
    $s3270->sequence_3270('ENTER',);
}

sub run {
    my ($self) = @_;
    my $ipl_from = get_var('IPL_FROM', '150');
    select_console 'x3270';
    get_to_system($ipl_from);
}

1;
