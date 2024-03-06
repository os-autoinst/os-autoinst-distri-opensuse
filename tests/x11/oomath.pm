# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libreoffice-math
# Summary: Test formula rendering in oomath
# Maintainer: QE Core <qe-core@suse.de>
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

    # Focus in LO 24.2 is by default in graphic window, no longer text window,
    # See https://progress.opensuse.org/issues/156628
    assert_and_click "oomath-textfield-ready";

    # be more resilient during the automatic evaluation of formulas to prevent
    # mistyping with slow typing and retrying.
    my $retries = 7;
    for (1 .. $retries) {
        type_string_slow "E %PHI = H %PHI\nnewline\n1 = 1";
        last if check_screen('test-oomath-1', 2);
        die "Could not match on correct formula within multiple retries" if $_ == $retries;
        record_info 'workaround', 'retrying unstable formula typing, see https://progress.opensuse.org/issues/53795 for details';
        send_key 'ctrl-a';
        send_key 'delete';
    }

    send_key 'alt-f4';
    assert_screen 'dont-save-libreoffice-btn';
    assert_and_click 'dont-save-libreoffice-btn' if match_has_tag('dont-save-libreoffice-btn');
}

1;
