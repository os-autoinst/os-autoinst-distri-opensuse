# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class is a parent for all Installation Pages. Introduces
# accessing methods to the elements that are common for all the pages.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::AbstractPage;
use strict;
use warnings FATAL => 'all';
use Installation::NavigationPanel;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        NavigationPanel => Installation::NavigationPanel->new()
    }, $class;
}

sub get_navigation_panel {
    my ($self) = @_;
    return $self->{NavigationPanel};
}

1;
