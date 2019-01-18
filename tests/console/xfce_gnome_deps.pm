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

use base "consoletest";
use strict;
use warnings;
use testapi;

# show installed GNOME components, allows to look for possibly unwanted
# dependencies

# this part contains the steps to run this test
sub run {
    my $self = shift;

    select_console 'user-console';
    script_run('rpm -qa "*nautilus*|*gnome*" | sort | tee /tmp/xfce-gnome-deps');
    upload_logs "/tmp/xfce-gnome-deps";
    # no further checks
    $self->result('ok');

}

1;
