# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";

use testapi;

use strict;
use warnings;
use backend::console_proxy;
use English;
use feature qw/say/;


sub run() {
    my $self = shift;

    # FIXME: iucvconn is not known there
    select_console('iucvconn');
    console('iucvconn')->kill_ssh;

    my $s3270 = console('x3270');

    # FIXME: Debug output just for now
    use Data::Dumper;
    print "==== DUMPER ====\n";
    say Dumper($s3270);
    say Dumper($s3270->expect_3270);
    my $r;
    $r = $s3270->expect_3270(
        output_delim => qr/.*login.*/,
        timeout      => 300
    );

    reset_consoles;

    if (!check_var('DESKTOP', 'textmode')) {
        select_console('x11');
    }
}

1;
