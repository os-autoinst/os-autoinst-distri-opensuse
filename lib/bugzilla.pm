# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package bugzilla;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use Mojo::UserAgent;
use XML::Simple;

our @EXPORT = qw(
  bugzilla_buginfo
);

=head1 SYNOPSIS

Tools for querying bug info from Bugzilla.
=cut

sub parse_buginfo {
    my $xml = shift;
    my $parser = XML::Simple->new;
    my $ret;

    eval {
        my $tmp = $parser->parse_string($xml);
        $tmp = $tmp->{bug} if exists $tmp->{bug} && !exists $tmp->{bug_id};
        die 'XML file does not match Bugzilla bug schema'
          if !exists $tmp->{bug_id};
        $ret = $tmp;
    };

    diag("Error parsing Bugzilla XML: $@") if $@;
    return $ret;
}

=head2 bugzilla_buginfo

 bugzilla_buginfo($bug_id);

Query bug status for given bug ID. C<BUGZILLA_URL> job setting is required,
otherwise this function will simply return C<undef>. The URL must contain
the string C<@BUGID@> which will be replace by the bug ID.

Returns a hash with bug status fields, or C<undef> on error.

Note that Bugzilla may return permission error in which case the hash will
contain only two entries: C<bug_id> and C<error>. It is up to you to handle
this possibility.

=cut

sub bugzilla_buginfo {
    my $bugid = shift;
    my $url = get_var('BUGZILLA_URL');
    my $ret;

    return undef unless $url;
    $url =~ s/\@BUGID@/$bugid/g;
    diag("Downloading bug info: $url");

    eval {
        my $msg = Mojo::UserAgent->new->get($url)->result;
        diag("Bugzilla response: $msg->{code}");
        $ret = $msg->body if $msg->is_success;
    };

    diag("Bugzilla query failed: $@") if $@;
    return defined($ret) ? parse_buginfo($ret) : undef;
}

1;
