#! /usr/bin/perl -w

use strict;
use warnings;

use File::Basename;
use YAML::PP;
use YAML::PP::Schema::Include;
use YAML::PP::Common 'PRESERVE_ORDER';

my $root_project_dir = dirname(__FILE__) . '/../';
my $include = YAML::PP::Schema::Include->new(paths => ($root_project_dir));
my $ypp = YAML::PP->new(
    schema => ['Core', $include, 'Merge'],
    preserve => PRESERVE_ORDER
);
$include->yp($ypp);

my $YAML_SCHEDULE_DEFAULTS = 'schedule/yast2/defaults/sle-15-sp4-x86_64-svirt-xen-pv.yaml';
my $YAML_SCHEDULE_BASE_ON = 'guided+gnome+part_val';
my $YAML_SCHEDULE = 'schedule/yast2/ext4.yaml';

my $schedule_defaults = $ypp->load_file($root_project_dir . $YAML_SCHEDULE_DEFAULTS);
my $base_on = $schedule_defaults->{$YAML_SCHEDULE_BASE_ON};
my $schedule = $ypp->load_file($root_project_dir . $YAML_SCHEDULE);

my @overriden_schedule = ();
for my $k (keys %$base_on) {
    if (exists $schedule->{schedule}{$k}) {
        push @overriden_schedule, $schedule->{schedule}{$k}->@*;
    }
    else {
        push @overriden_schedule, $base_on->{$k}->@*;
    }
}
print $ypp->dump_string(\@overriden_schedule);

