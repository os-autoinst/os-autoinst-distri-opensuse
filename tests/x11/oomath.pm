# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test formula rendering in oomath
# Maintainer: Oliver Kurz <okurz@suse.de>
# - Launch oomath
# - Enter formula
# - Select text and replace
# - Test undo
# - Close oomath
# Tags: https://bugs.freedesktop.org/show_bug.cgi?id=42301

use base 'x11test';
use strict;
use warnings;
use testapi;
use utils 'type_string_slow';

sub run {
    my ($self) = shift;

    $self->libreoffice_start_program('oomath');
    # be more resilient during the automatic evaluation of formulas to prevent
    # mistyping with slow typing and retrying.
    my $retries = 7;
    for (1 .. $retries) {
        type_string_slow "E %PHI = H %PHI\nnewline\n1 = 1";
        last if check_screen [qw(test-oomath-1 oomath-bsc1127895)];
        die "Could not match on correct formula within multiple retries" if $_ == $retries;
        record_info 'workaround', 'retrying unstable formula typing, see https://progress.opensuse.org/issues/53795 for details';
        send_key 'ctrl-a';
        send_key 'delete';
    }
    if (match_has_tag('oomath-bsc1127895')) {
        record_soft_failure 'bsc#1127895';
        send_key 'alt-f4';
    } else {
        send_key 'alt-f4';
        assert_and_click 'dont-save-libreoffice-btn';    # _Don't save
    }
}

1;
