# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Select given PATTERNS
#    You can pass
#    PATTERNS=minimal,base or
#    PATTERNS=all to select all of them
#    PATTERNS=default,web,-x11,-gnome to keep the default but add web and
#    remove x11 and gnome
#
#    For this you need to have needles that provide pattern-base,
#    pattern-minimal...
#    additional to the on-pattern tag
# Maintainer: slindomansilla <slindomansilla@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use utils 'type_string_slow';

sub run {
    my ($self) = @_;
    $self->go_to_patterns();
    $self->process_patterns();
    $self->accept_changes();
}

sub post_fail_hook {
    my $self = shift;

    select_console 'log-console';
    my $ret = script_output("grep -E -m 1 \"nothing provides\" /var/log/YaST2/y2log", proceed_on_failure => 1);
    record_info("Conflict:", $ret, result => 'fail') if ($ret);
    $self->SUPER::post_fail_hook();
}

1;
