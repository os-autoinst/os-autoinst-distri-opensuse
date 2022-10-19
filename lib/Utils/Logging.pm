# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

=head1 Utils::Logging

C<Utils::Logging> - Save logs directly on the worker for offline upload via ulogs 

=cut

package Utils::Logging;

use base 'Exporter';
use Exporter;
use strict;
use warnings;
use Mojo::File qw(path);

our @EXPORT = qw(save_ulog);

=head2

save_ulog($out $filename);

Creates a file from a string, the file is then saved in the ulogs directory of the worker running isotovideo. 
This is particularily useful when the SUT has no network connection.

example: 

$out = script_output('journalctl --no-pager -axb -o short-precise');
$filename = "my-test.log";

=cut

sub save_ulog {
    my ($out, $filename) = @_;
    mkdir('ulogs') if (!-d 'ulogs');
    path("ulogs/$filename")->spurt($out);    # save the logs to the ulogs directory on the worker directly
}

1;
