# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Shift product version for upgrade test
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;

    my $nver;
    my $cver = get_var('VERSION');

    # Parse new version from module name
    if ($self->{name} =~ 'inc|dec') {
        $nver = $cver + 1 if $self->{name} =~ 'inc';
        $nver = $cver - 1 if $self->{name} =~ 'dec';
        $nver = sprintf("%.1f", $nver);
    }
    elsif ($self->{name} =~ '=') {
        $nver = (split /=/, $self->{name})[1];
    }
    else {
        die "Can't parse version from $self->{name}";
    }

    set_var('VERSION', $nver, reload_needles => 1);
    record_info "version $cver>$nver", "Version shifted from $cver to $nver";
}

1;
