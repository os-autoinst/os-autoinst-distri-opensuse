# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1479504: Firefox: Health Report

# Summary: Case#1479504: Firefox: Health Report
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run() {
    my ($self) = @_;
    $self->start_firefox;

    send_key "alt-h";
    sleep 1;
    send_key "e";
    check_screen('firefox-health-report', 60);

    send_key "/";
    sleep 1;
    type_string "raw data\n";
    check_screen('firefox-health-report-rawdata', 60);

    $self->exit_firefox;
}
1;
# vim: set sw=4 et:
