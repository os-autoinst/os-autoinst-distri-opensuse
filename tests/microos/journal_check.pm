# SUSE's openQA tests
#
# Copyright © 2017-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic MicroOS journal tests
# Maintainer: qa-c team <qa-c@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use microos;
use version_utils 'is_opensuse';
use Mojo::JSON qw(decode_json);

sub parse_bug_refs {
    my $res            = shift;
    my $tested_product = get_required_var('DISTRI');
    my $tested_version = get_required_var('VERSION');
    my %bp;

    my $bugs = decode_json($res->body);
    foreach my $bugid (keys %$bugs) {
        if (exists $bugs->{$bugid}->{products}->{$tested_product} && ref $bugs->{$bugid}->{products}->{$tested_product} eq ref []) {
            foreach my $ver (@{$bugs->{$bugid}->{products}->{$tested_product}}) {
                if ($ver eq $tested_version) {
                    $bp{$bugid} = {%{$bugs->{$bugid}}{qw(type description)}};
                    last;
                }
            }
        } else {
            bmwqemu::diag("Versions of a product in journal_check::bug_refs.json should be stored in an array, or the product key is missing!");
        }
    }
    return !%bp ? undef : \%bp;
}

sub run {
    my $self = shift;
    my $res  = Mojo::UserAgent->new->get(data_url('journal_check/bug_refs.json'))->result;
    $res->is_success or die "Could not download file with bug refs";
    my $bug_pattern = parse_bug_refs($res);

    $self->select_serial_terminal;

    my @journal_output = split(/\n/, script_output("journalctl --no-pager -p ${\get_var('JOURNAL_LOG_LEVEL', 'err')} -o short-precise | tail -n +2"));

    # Find lines which matches to the pattern_bug
    foreach my $bug (keys %$bug_pattern) {
        my $buffer = "";
        foreach my $line (@journal_output) {
            $buffer .= $line . "\n" if ($line =~ /$bug_pattern->{$bug}->{description}/);
        }
        if ($buffer) {
            if ($bug_pattern->{$bug}->{type} eq 'feature') {
                record_info($bug, $buffer);
            } elsif ($bug_pattern->{$bug}->{type} eq 'ignore') {
                bmwqemu::diag("Ignoring log message:\n$buffer\n");
            } else {
                record_soft_failure("$bug:\n$buffer");
            }
        }
    }

    my $failed;
    # Find lines which doesn't match to the pattern_bug by using master_pattern
  OUT: foreach my $line (@journal_output) {
        foreach my $mp (map { $bug_pattern->{$_}->{description} } keys %$bug_pattern) {
            next OUT if ($line =~ /$mp/);
        }
        record_info('Unknown issue', $line, result => 'fail');
        $failed = 1;
    }

    # Write full journal output for reference and upload it into Uploaded Logs section in test webUI
    script_run("journalctl --no-pager -o short-precise > /tmp/full_journal.log");
    upload_logs "/tmp/full_journal.log";

    # Check for failed systemd services and examine them
    # script_run("pkill -SEGV dbus-daemon"); # comment out for a test
    my $failed_services = script_output("systemctl --failed --no-legend --plain --no-pager");
    foreach my $line (split(/\n/, $failed_services)) {
        if ($line =~ /^([\w.-]+)\s.+$/) {
            my $failed_service_output = script_output("systemctl status $1 -l || true");
            record_info "$1 failed", $failed_service_output, result => 'fail';
            $failed = 1;
        }
    }
    $self->result('fail') if $failed;
}

1;
