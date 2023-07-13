# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces checkbox as a UI element with its accessing
# methods.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Element::Checkbox;
use strict;
use warnings FATAL => 'all';
use testapi;

sub new {
    my ($class, %args) = @_;
    my $self = bless {
        checked_needle => $args{checked_needle},
        unchecked_needle => $args{unchecked_needle},
        shortcut => $args{shortcut}
    }, $class;
}

=head2 is_checked(%args)

    is_checked(checked_needle => $checked_needle, unchecked_needle => $unchecked_needle);

The method to verify if the checkbox is checked or not.

C<$checked_needle> - String, needle tag for checkbox in checked state;
C<$unchecked_needle> - String, needle tag for checkbox in unchecked state.

NOTE: To use the method, the appropriate needles with the checked and unchecked
states should be added to the needles repository.

Returns 1 if the checkbox is checked, otherwise returns 0.

Example:

    There is the checkbox with 'Test' label.

    First of all create two needles for it:
    * in checked state with 'checked_test_checkbox' tag;
    * in unchecked state with 'unchecked_test_checkbox' tag.

    Then use the method:

    is_checked(checked_needle   => 'checked_test_checkbox',
               unchecked_needle => 'unchecked_test_checkbox');

=cut

sub is_checked {
    my ($self, %args) = @_;
    my $checked_needle = $args{checked_needle},
      my $unchecked_needle = $args{unchecked_needle};

    # If assert_screen do not fail, it means one of the needles matched.
    # In this case, just check if it matches 'checked' state.
    # If not, it means that it matched 'unchecked' state and there is no need
    # to do one more verification, just return 0.
    assert_screen([($checked_needle, $unchecked_needle)]);
    if (match_has_tag($checked_needle)) {
        return 1;
    }
    return 0;
}

=head2 set_state(%args)

    set_state(state => $state, shortcut => $shortcut, needle_postfix => $needle_postfix);

The method to set the checkbox to checked or unchecked state, regardless of the
current state of the checkbox.

C<$state> - Boolean, specifies whether to check (1) or uncheck (0) the checkbox;
C<$shortcut> - String, keyboard shortcut for the checkbox (e.g. alt-a);
C<$checked_needle> - String, needle tag for checkbox in checked state;
C<$unchecked_needle> - String, needle tag for checkbox in unchecked state.

NOTE: To use the method, the appropriate needles with the checked and unchecked
states should be added to the needles repository.

Example:

    There is a checkbox. It is required to test the functionality that it
    enables and do not care about the default state of the checkbox.

    Assume, needles for checked/unchecked states already created.

    Method usage:

    set_state(state            => 1,
              shortcut         => 'alt-a',
              checked_needle   => 'checked_test_checkbox',
              unchecked_needle => 'unchecked_test_checkbox'
    );

=cut

sub set_state {
    my ($self, %args) = @_;
    my $state = $args{state};
    my $shortcut = $args{shortcut};
    my $checked_needle = $args{checked_needle},
      my $unchecked_needle = $args{unchecked_needle};

    # Check if the checkbox already in the required state. If so, just skip.
    if ($state == $self->is_checked(checked_needle => $checked_needle,
            unchecked_needle => $unchecked_needle)) {
        return;
    }
    send_key($shortcut);
}


1;
