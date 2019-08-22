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
use testapi qw(get_var set_var);
use main_common 'loadtest';
use YAML::Tiny;

our @EXPORT = qw(load_yaml_schedule get_test_data);

my $test_data;
my $include_tag = "!include";

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

=head2 get_test_data

Returns test data parsed from the yaml file.

=cut

sub get_test_data {
    return $test_data;
}

=head2 parse_test_data

Parse test data from the yaml file which contains data used in the tests which could be located
in the same file than the schedule or in a dedicated file only for data.

=cut

sub parse_test_data {
    my ($schedule) = shift;
    $test_data = {};
    # return if section is not defined
    return unless exists $schedule->{test_data};

    if (defined(my $import = $schedule->{test_data}->{$include_tag})) {
        # Allow both lists and scalar value for import "!include" key
        if (ref $import eq 'ARRAY') {
            for my $include (@{$import}) {
                _import_test_data_from_yaml($include);
            }
        }
        else {
            _import_test_data_from_yaml($import);
        }
    }
    # test_data from schedule file has priority over imported one
    $test_data = {%$test_data, %{$schedule->{test_data}}};
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
        parse_test_data($schedule);
        loadtest($_) for (@schedule_modules);
        return 1;
    }
    return 0;
}

sub _import_test_data_from_yaml {
    my ($yaml_file) = @_;
    my $include_yaml = YAML::Tiny::LoadFile(dirname(__FILE__) . '/../' . $yaml_file);
    if (exists $include_yaml->{$include_tag}) {
        die "Error: test_data can only be defined in a dedicated file for data\n";
    }
    $test_data = {%$test_data, %{$include_yaml}};
}

1;
