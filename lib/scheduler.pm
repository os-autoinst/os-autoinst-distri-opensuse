# Copyright © 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package scheduler;

use base Exporter;
use Exporter;

use strict;
use warnings;

use File::Basename;
use testapi qw(get_var set_var diag);
use main_common 'loadtest';
use YAML::Tiny;
use Data::Dumper;

our @EXPORT = qw(load_yaml_schedule get_test_suite_data);

my $test_suite_data;
my $include_tag = '$include';

sub parse_vars {
    my ($schedule) = shift;
    my %vars;
    while (my ($var, $value) = each %{$schedule->{vars}}) {
        $value =~ s/%(.*?)%/get_var($1)/eg;
        $vars{$var} = $value;
    }
    return %vars;
}

sub parse_schedule {
    my ($schedule) = shift;
    my @scheduled;
    for my $module (@{$schedule->{schedule}}) {
        push(@scheduled, $module) && next unless ($module =~ s/\{\{(.*)\}\}/$1/);
        # Module is scheduled conditionally. Need to be parsed. Get condition hash
        my $condition = $schedule->{conditional_schedule}->{$module};
        # Iterate over variables in the condition
        foreach my $var (keys %{$condition}) {
            next unless my $val = get_var($var);
            # If value of the variable matched the conditions
            # Iterate over the list of the modules to be loaded
            push(@scheduled, $_) for (@{$condition->{$var}->{$val}});
        }
    }
    return @scheduled;
}

=head2 get_test_suite_data

Returns test data parsed from the yaml file.

=cut

sub get_test_suite_data {
    return $test_suite_data;
}

=head2 parse_test_suite_data

Parse test data from the yaml file which contains data used in the tests which could be located
in the same file than the schedule or in a dedicated file only for data.

=cut

sub parse_test_suite_data {
    my ($schedule) = shift;
    $test_suite_data = {};

    # if test_data section is defined in schedule file
    if (exists $schedule->{test_data}) {
        # import test data using $include from test_data section in schedule file
        _import_test_data_included($schedule->{test_data});

        # test_data from schedule file has priority over included data
        $test_suite_data = {%$test_suite_data, %{$schedule->{test_data}}};
    }

    # import test data directly from data file
    if (my $yamlfile = get_var('YAML_TEST_DATA')) {
        # test data from data file has priority over test_data from schedule
        _import_test_data_from_yaml(path => $yamlfile, allow_included => 1);
    }
    diag(Dumper($test_suite_data));
}

=head2 load_yaml_schedule

Parse variables and test modules from a yaml file representing a test suite to be scheduled.

=cut

sub load_yaml_schedule {
    if (my $yamlfile = get_var('YAML_SCHEDULE')) {
        my $schedule      = YAML::Tiny::LoadFile(dirname(__FILE__) . '/../' . $yamlfile);
        my %schedule_vars = parse_vars($schedule);
        while (my ($var, $value) = each %schedule_vars) { set_var($var, $value) }
        my @schedule_modules = parse_schedule($schedule);
        parse_test_suite_data($schedule);
        loadtest($_) for (@schedule_modules);
        return 1;
    }
    return 0;
}

sub _import_test_data_included {
    my ($test_data) = shift;

    if (defined(my $import = $test_data->{$include_tag})) {
        # Allow both lists and scalar value for import "$include" key
        if (ref $import eq 'ARRAY') {
            for my $include (@{$import}) {
                _import_test_data_from_yaml(path => $include);
            }
        }
        else {
            _import_test_data_from_yaml(path => $import);
        }
        delete $test_data->{$include_tag};
    }
}

sub _ensure_include_not_present {
    my ($include_yaml) = shift;
    if (exists $include_yaml->{$include_tag}) {
        die "Error: please define in the file only the content of your test_data," .
          " without including tag $include_tag\n";
    }
}

sub _import_test_data_from_yaml {
    my (%args) = @_;

    my $include_yaml = YAML::Tiny::LoadFile(dirname(__FILE__) . '/../' . $args{path});
    if ($args{allow_included}) {
        # import test data using $include from test data file
        _import_test_data_included($include_yaml);
    }
    _ensure_include_not_present($include_yaml);
    # latest included data has priority over previous included data
    $test_suite_data = {%$test_suite_data, %{$include_yaml}};
}

1;
