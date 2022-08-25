#!/usr/bin/perl

# Tool to merge YAML_SCHEDULE_DEFAULT  with YAML_SCHEDULE_FLOWS
# and YAML_SCHEDULE.

use strict;
use warnings;
use File::Basename;

use Cwd;

use YAML::PP;
use YAML::PP::Schema::Include;
use YAML::PP::Common 'PRESERVE_ORDER';

my $test_suite_data;
my $root_project_dir = getcwd;
my $include = YAML::PP::Schema::Include->new(paths => ($root_project_dir));
my $ypp = YAML::PP->new(
    schema => ['Core', 'Merge'],
    preserve => PRESERVE_ORDER
);
$include->yp($ypp);


my $yamlfile = $ENV{YAML_SCHEDULE};
my $schedule_file = $ypp->load_file($yamlfile);
parse_schedule($schedule_file);


sub parse_schedule {
    my ($schedule) = shift;
    my @scheduled;

    # schedule contains keys and is based on a list of files representing schedule flows
    if (ref $schedule->{schedule} eq 'HASH') {
        my $default_path = $ENV{YAML_SCHEDULE_DEFAULT};
        die "You need to provide'YAML_SCHEDULE_DEFAULT' when using this script." unless $default_path;
        my $default_flow = $ypp->load_file($default_path);

        my $additional_flows = {};
        if (my @flows = split(/,/, ($ENV{YAML_SCHEDULE_FLOWS}))) {
            # all flows are expected to be in the same path than the default.yaml
            my (undef, $flows_path, undef) = fileparse($default_path, '.yaml');

            # merge flows
            for my $flow (@flows) {
                # latest flow has priority over previous processed flows
                $additional_flows = {
                    %{$additional_flows},
                    %{$ypp->load_file($flows_path . $flow . '.yaml')}
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
        die "You're trying to apply this script to a list of test modules instead " .
          "to a default based schedule.";
    }
    print($ypp->dump_string(\@scheduled));
    return @scheduled;
}

=head1 helper_default_based_schedule

Tool to merge YAML schedules for openQA based on defaults, flows
and an individual YAML schedule.

=head2 USAGE

  YAML_SCHEDULE_DEFAULT=<path to default schedule> \\
  YAML_SCHEDULE_FLOWS=<comma-separated list of flows> \\
  YAML_SCHEDULE=<path to individual schedule> \\
  tools/helper_default_based_schedule

This makes use of the openQA YAML scheduler. The resulting vars and schedule
are printed out as diag information on STDERR.

=cut
