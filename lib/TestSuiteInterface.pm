# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Parent class used as Interface which test suites classes
# inherit and implement

package TestSuiteInterface {
    use File::Find;
    use File::Basename;

    BEGIN {
        unshift @INC, dirname(__FILE__) . '/../../lib';
    }

    sub new {
        my ($class, $name) = @_;
        my $self = {};
        $self->{name} = $name;
        bless $self, $class;
        return $self;
    }

    sub getVariables {
        my ($self) = shift;
        return $self->{variables};
    }

    # parses and loads the modules of a test suite
    sub loadtests {
        my ($self) = shift;
        {
            die "oops" unless $self->{scheduler_order};
            $_->() for (@{$self->{scheduler_order}});
            return 1;
        }
        return 0;
    }

    # Defines the scheduler variable. Due to the scheduler needs to be in order
    # another variable got introduced which stores the loadtest command in the
    # correct sequence.
    #https://gist.github.com/perlpunk/1a91716e994e1c13605310ed06287584
    sub set_scheduler {
        my ($self, @list) = @_;
        # get a list of the subroutines of the hash
        my @order    = map { $list[($_ * 2) + 1] } 0 .. (@list / 2) - 1;
        my %schedule = @list;
        $self->{scheduler}       = \%schedule;
        $self->{scheduler_order} = \@order;
        return $self;
    }
}

1;
