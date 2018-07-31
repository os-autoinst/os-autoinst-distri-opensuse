# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Rework the tests layout.
# Maintainer: Alberto Planas <aplanas@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self   = shift;
    my $iso    = get_var("ISO") || get_var('HDD_1');
    my $size   = $iso ? -s $iso : 0;
    my $result = 'ok';
    my $max    = get_var("ISO_MAXSIZE", 0);
    if (!$size || !$max || $size > $max) {
        if (check_var('VERSION', '12-SP4') && check_var('FLAVOR', 'Desktop-DVD')) {
            record_soft_failure("bsc#1101761 - SLED ISO size is over limit");
        }
        else {
            $result = 'fail';
        }
    }
    if (!defined $size) {
        diag("iso path invalid: $iso");
    }
    else {
        diag("check if actual iso size $size fits $max: $result");
    }
    $self->result($result);
}

1;
