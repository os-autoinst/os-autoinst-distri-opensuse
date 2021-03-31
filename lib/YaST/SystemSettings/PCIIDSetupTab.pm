# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for PCI ID Setup
# Tab of systems settings YaST module.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::SystemSettings::PCIIDSetupTab;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{menu_btn_add} = $self->{app}->menucollection({label => 'Add...'});
    $self->{btn_delete}   = $self->{app}->button({id => 'delete'});
    return $self;
}

sub press_add_pci_id_from_list {
    my ($self) = @_;
    $self->{menu_btn_add}->select('&From List');
    return $self;
}

sub press_delete {
    my ($self) = @_;
    $self->{btn_delete}->click();
    return $self;
}

1;
