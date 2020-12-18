# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces methods in Expert Partitioner to handle
# a generic confirmation warning..
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::ConfirmationWarning;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{btn_yes}     = $self->{app}->button({id => 'yes'});
    $self->{btn_no}      = $self->{app}->button({id => 'no'});
    $self->{lbl_warning} = $self->{app}->label({type => 'YLabel'});
    return $self;
}

sub press_yes {
    my ($self) = @_;
    return $self->{btn_yes}->click();
}

sub press_no {
    my ($self) = @_;
    return $self->{btn_no}->click();
}

sub text {
    my ($self) = @_;
    return $self->{lbl_warning}->text();
}

sub confirm_warning_only_use_if_familiar {
    my ($self) = @_;
    $self->ensure_correct_text(
        qr/Only use this program if you are familiar with partitioning hard disks/);
    $self->press_yes();
}

sub confirm_warning_delete_partition {
    my ($self, $part_name) = @_;
    $self->ensure_correct_text(qr/Really delete \/dev\/$part_name?/);
    $self->press_yes();
}

sub confirm_warning_delete_volume_group {
    my ($self, $vg) = @_;
    $self->ensure_correct_text(
        qr/Really delete volume group \"$vg\" and all related logical volumes?/);
    $self->press_yes();
}

sub ensure_correct_text {
    my ($self, $expected) = @_;
    if (my $text = $self->text() !~ $expected) {
        die "Unexpected warning found: text on warning does not match:\n" .
          "text: $text\nregex:$expected";
    }
}

1;
