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

# Summary: Override known failures for QAM
# Maintainer: Jan Baier <jbaier@suse.cz>

package LTP::WhiteList;

use base Exporter;
use strict;
use warnings;
use testapi;
use bmwqemu;
use Exporter;
use Mojo::UserAgent;
use Mojo::JSON;
use Mojo::File 'path';

our @EXPORT = qw(download_whitelist override_known_failures);

sub download_whitelist {
    my $path = get_required_var('LTP_KNOWN_ISSUES');
    my $res  = Mojo::UserAgent->new->get($path)->result;
    unless ($res->is_success) {
        record_info("File not downloaded!", $res->message, result => 'softfail');
        set_var('LTP_KNOWN_ISSUES', undef);
    }
    my $basename = $path =~ s#.*/([^/]+)#$1#r;
    save_tmp_file($basename, $res->body);
    set_var('LTP_KNOWN_ISSUES', hashed_string($basename));
    mkdir('ulogs') if (!-d 'ulogs');
    bmwqemu::save_json_file($res->json, "ulogs/$basename");
}

sub override_known_failures {
    my ($self, $env, $suite, $test) = @_;

    my $content = path(get_required_var('LTP_KNOWN_ISSUES'))->slurp;
    my $issues  = Mojo::JSON::decode_json($content);
    return unless $issues;
    return unless exists $issues->{$suite};

    my @issues;
    if (ref($issues->{$suite}) eq 'ARRAY') {
        @issues = @{$issues->{$suite}};
    }
    else {
        return unless exists $issues->{$suite}->{$test};
        @issues = @{$issues->{$suite}->{$test}};
    }

  ISSUE:
    foreach my $cond (@issues) {
        foreach my $filter (qw(product ltp_version revision arch kernel)) {
            next ISSUE if exists $cond->{$filter} and $env->{$filter} !~ m/$cond->{$filter}/;
        }

        bmwqemu::diag("Failure in LTP:$suite:$test is known, overriding to softfail");
        $self->{result} = 'softfail';
        last;
    }
}

1;
