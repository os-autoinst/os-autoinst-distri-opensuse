# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;

# work around for broken base in perl < 5.20
## no critic (RequireBarewordIncludes)
# use base qw(shutdown);
require 'shutdown.pm';
our @ISA;
push @ISA, 'shutdown';
## use critic

use testapi;

sub trigger_shutdown_gnome_button() {
    my ($self) = @_;

    wait_idle;
    send_key "alt-f1";    # applicationsmenu
    my $selected = check_screen 'shutdown_button', 0;
    if (!$selected) {
        send_key_until_needlematch 'shutdown_button', 'tab';    # press tab till is shutdown button selected
    }
    send_key "ret";                                             # press shutdown button
}

1;
# vim: set sw=4 et:

