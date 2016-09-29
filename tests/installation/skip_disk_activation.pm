# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: an experimental bootloader using virsh over ssh
# G-Maintainer: Stephan Kulow <coolo@suse.de>

use base "y2logsstep";
use strict;
use testapi;

sub run {
    my $self = shift;

    record_soft_failure 'we should not have it';
    sleep 3;
    send_key $cmd{next};
    sleep 5;
}

1;
# vim: set sw=4 et:
