# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Factory for Test Suites classes

package SchedulerFactory {
    use TestSuiteAbstract;

    sub new {
        my ($class, $testname) = @_;
        my $self = {
            testname_factory => TestSuiteAbstract::getTestSuite($testname)
        };
        bless $self, $class;
        return $self;
    }

    # returns an instance of the factory
    sub createScheduler {
        my ($self) = shift;
        $self->{testname_factory};
    }
}

1;
