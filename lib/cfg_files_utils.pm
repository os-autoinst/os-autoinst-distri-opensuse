# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Shared library for validating and manipulating
#          configuration files in the SUT.

package cfg_files_utils;
use Exporter 'import';
use strict;
use warnings;
use Test::Assert ':all';
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use testapi;

our @EXPORT = qw(
  validate_cfg_file
  compare_settings
);

=head2 compare_settings

  compare_settings({ expected => $value_1, current => value_2 })

Method validates that the given hash references contain the
same data. In any other case, the data from both structures 
are printed, accompanied by an error message.

=cut

sub compare_settings {
    my ($args) = @_;
    eval {
        assert_deep_equals($args->{expected}, $args->{current});
        record_info("Compare settings", "Settings comparison passed");
    } or do {
        print "$@\n";
        die "The system settings deviate from expectations. \n
    Expected: " . Dumper($args->{expected}) . "\nGot: " . Dumper($args->{current}) . "\n";
    };
}

=head2 validate_cfg_file

  validate_cfg_file($args)

Method validates content of the config file. Method allows to validate
file by the line content or by providing key-pair values for the
configuration files which use "KEY=PAIR" syntax.

Following structure is expected for the input:
configuration_files:
  - path: /etc/hosts
    entries:
      - '10.226.154.19\tnew.entry.de h999uz'
      - '127.0.0.1\tlocalhost'
  - path: /etc/sysconfig/kdump
    settings:
      KDUMP_DUMPLEVEL: 31
      KDUMP_DUMPFORMAT: lzo
=cut

sub validate_cfg_file {
    my ($args) = @_;
    # Accumulate errors
    my $errors = '';
    foreach my $cfg_file (@{$args}) {
        my $path = $cfg_file->{path};
        if ($cfg_file->{empty}) {
            if (script_run("[ -s $path ]") == 0) {
                $errors .= "No entries should be found in '$path'.\n";
            }
            next;
        }

        my $cfg_content = script_output("cat $path");

        for my $setting (keys %{$cfg_file->{settings}}) {
            my ($conf_line) = grep { /$setting=/ } split(/\n/, $cfg_content);
            unless ($conf_line) {
                $errors .= "Setting '$setting' not found in $path.\n";
                next;
            }
            my $value = $cfg_file->{settings}->{$setting};
            if ($conf_line !~ /^$setting=[",']?$value[",']?$/) {
                $errors .= "Setting '$setting' with value '$value' not found in $path.\n";
            }
        }

        foreach my $entry (@{$cfg_file->{entries}}) {
            if ($cfg_content !~ /$entry/) {
                $errors .= "Entry '$entry' is not found in '$path'.\n";
            }
        }

        foreach my $not_entry (@{$cfg_file->{not_entries}}) {
            if ($cfg_content =~ /$not_entry/) {
                $errors .= "Unexpected entry '$not_entry' was found in '$path'.\n";
            }
        }
    }

    die "Configuration files validation failed:\n$errors" if $errors;
}

1;
