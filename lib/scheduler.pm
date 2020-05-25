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
use YAML::PP;
use YAML::PP::Schema::Include;
use Data::Dumper;

our @EXPORT = qw(load_yaml_schedule get_test_suite_data);

my $test_suite_data;
my $root_project_dir = dirname(__FILE__) . '/../';

my $include = YAML::PP::Schema::Include->new(paths => ($root_project_dir));
my $ypp     = YAML::PP->new(schema => ['Core', $include, 'Merge']);
$include->yp($ypp);

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
    if (exists $schedule->{test_data}) {
        $test_suite_data = {%$test_suite_data, %{$schedule->{test_data}}};
    }
    # import test data directly from data file
    if (my $yamlfile = get_var('YAML_TEST_DATA')) {
        my $include_yaml = $ypp->load_file($root_project_dir . $yamlfile);
        # latest included data has priority over previous included data
        $test_suite_data = {%$test_suite_data, %{$include_yaml}};
    }
    local $Data::Dumper::Terse = 1;
    my $out = Dumper($test_suite_data);
    chomp($out);
    diag("parse_test_suite_data: $out");
}

=head2 load_yaml_schedule

Parse variables and test modules from a yaml file representing a test suite to be scheduled.

=cut

sub load_yaml_schedule {
    if (my $yamlfile = get_var('YAML_SCHEDULE')) {
        my $schedule      = $ypp->load_file($root_project_dir . $yamlfile);
        my %schedule_vars = parse_vars($schedule);
        while (my ($var, $value) = each %schedule_vars) { set_var($var, $value) }
        my @schedule_modules = parse_schedule($schedule);
        parse_test_suite_data($schedule);
        loadtest($_) for (@schedule_modules);
        return 1;
    }
    return 0;
}

1;
