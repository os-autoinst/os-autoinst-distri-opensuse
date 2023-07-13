# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

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
use YAML::PP::Common 'PRESERVE_ORDER';

our @EXPORT = qw(load_yaml_schedule get_test_suite_data);

my $test_suite_data;
my $root_project_dir = dirname(__FILE__) . '/../';
my $include = YAML::PP::Schema::Include->new(paths => ($root_project_dir));
my $ypp = YAML::PP->new(
    schema => ['Core', $include, 'Merge'],
    preserve => PRESERVE_ORDER
);
$include->yp($ypp);

sub parse_vars {
    my ($schedule) = shift;
    my %vars;
    while (my ($var, $value) = each %{$schedule->{vars}}) {
        $value =~ s/%(.*?)%/get_var($1)/eg;
        $vars{$var} = $value;
    }
    diag('parse_vars (variables parsed from YAML schedule):');
    diag($ypp->dump_string(\%vars));
    return %vars;
}

sub parse_schedule {
    my ($schedule) = shift;
    my @scheduled;

    # schedule contains keys and is based on a list of files representing schedule flows
    if (ref $schedule->{schedule} eq 'HASH') {
        my $default_path = get_var('YAML_SCHEDULE_DEFAULT');
        die "openQA setting 'YAML_SCHEDULE_DEFAULT' should be provided when using keys to be overriden " .
          "instead of a list of test modules." unless $default_path;
        my $default_flow = $ypp->load_file($root_project_dir . $default_path);

        my $additional_flows = {};
        if (my @flows = split(/,/, get_var('YAML_SCHEDULE_FLOWS', ''))) {
            # all flows are expected to be in the same path than the default.yaml
            my (undef, $flows_path, undef) = fileparse($default_path, '.yaml');

            # merge flows
            for my $flow (@flows) {
                # latest flow has priority over previous processed flows
                $additional_flows = {
                    %{$additional_flows},
                    %{$ypp->load_file($root_project_dir . $flows_path . $flow . '.yaml')}
                };
            }
        }
        # schedule flow has priority over previous processed flows
        $additional_flows = {%{$additional_flows}, %{$schedule->{schedule}}};

        # create the final list of test modules
        for my $k (keys %$default_flow) {
            push @scheduled, exists $additional_flows->{$k} ?
              $additional_flows->{$k}->@*
              : $default_flow->{$k}->@*;
        }
    }
    # schedule contains a list of test modules
    else {
        for my $module (@{$schedule->{schedule}}) {
            push(@scheduled, parse_schedule_module($schedule, $module));
        }
    }
    diag($ypp->dump_string(\@scheduled));
    return @scheduled;
}

sub parse_schedule_module {
    my ($schedule, $module) = @_;
    my @scheduled;
    if ($module =~ s/\{\{(.*)\}\}/$1/) {
        # Module is scheduled conditionally. Need to be parsed. Get condition hash
        my $condition = $schedule->{conditional_schedule}->{$module};
        # Iterate over variables in the condition
        foreach my $var (keys %{$condition}) {
            my $val = get_var($var);
            next if (!defined $val);
            # If value of the variable matched the conditions
            # Iterate over the list of the modules to be loaded
            push(@scheduled, parse_schedule_module($schedule, $_)) for (@{$condition->{$var}->{$val}});
        }
    }
    else {
        push(@scheduled, $module);
    }
    return @scheduled;
}

=head2 get_test_suite_data

Returns test data parsed from the yaml file.

=cut

sub get_test_suite_data {
    return $test_suite_data;
}

=head2 expand_test_data_vars

Expand test suite data variables

=cut

sub expand_test_data_vars {
    my ($node) = shift;
    if (ref $node eq 'HASH') {
        $_ = expand_test_data_vars($_) foreach values %$node;
    } elsif (ref $node eq 'ARRAY') {
        $_ = expand_test_data_vars($_) foreach (@$node);
    } else {
        $node =~ s/%(.*?)%/get_var($1,'')/eg if $node;
    }
    return $node;
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
    expand_test_data_vars($test_suite_data);
    diag('parse_test_suite_data (data parsed from YAML test_data):');
    diag($ypp->dump_string($test_suite_data));
}

=head2 load_yaml_schedule

Parse variables and test modules from a yaml file representing a test suite to be scheduled.

=cut

sub load_yaml_schedule {
    if (my $yamlfile = get_var('YAML_SCHEDULE')) {
        my $filename = $root_project_dir . $yamlfile;
        if (!-e $filename) {
            # Write error to log to give the user the chance to understand, what went wrong
            diag("YAML_SCHEDULE file not found: '$filename'");
            # Note that openQA will terminate with "unable to load main.pm, check the log for the cause" on error at this stage.
            die "Provided YAML_SCHEDULE does not exist";
        }
        my $schedule_file = $ypp->load_file($filename);
        my %schedule_vars = parse_vars($schedule_file);
        my $test_context_instance = undef;
        while (my ($var, $value) = each %schedule_vars) { set_var($var, $value) }
        my @schedule_modules = parse_schedule($schedule_file);
        parse_test_suite_data($schedule_file);
        $test_context_instance = get_var('TEST_CONTEXT')->new() if defined get_var('TEST_CONTEXT');
        loadtest($_, run_args => $test_context_instance) for (@schedule_modules);
        return 1;
    }
    return 0;
}

1;
