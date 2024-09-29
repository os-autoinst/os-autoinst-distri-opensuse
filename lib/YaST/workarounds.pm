# Copyright 2015-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package YaST::workarounds;


use strict;
use warnings;
use Exporter 'import';
use testapi;
use utils;
use version_utils;
use Config::Tiny;

our @EXPORT = qw(
  apply_workaround_poo124652
);

=head1 Workarounds for known issues

=head2 apply_workaround_poo124652 ($mustmatch, [,[$timeout] | timeout => $timeout] ):

Workaround for the screen refresh issue.

First checks if we need to apply the workaround, if the needle matches 
already no workaround is required.

If the workaround is needed we record a soft failure and apply a 'shift-f3' 
and 'esc' sequence that should fix the problem

If the problem still persists (we saw one occasion in the VRs) then we retry
with maximazing and shrinking the screen twice by sending 'alt-f10' two times. 

=cut

sub apply_workaround_poo124652 {
    my ($mustmatch) = shift;
    my $timeout;
    $timeout = shift if (@_ % 2);
    my %args = (timeout => $timeout // 0, @_);
    if (!check_screen($mustmatch, %args)) {
        record_info('poo#124652', 'poo#124652 - gtk glitch not showing dialog window decoration on openQA');
        send_key('shift-f3', wait_screen_change => 1);
        check_screen('style-sheet-selection-popup', 10);
        send_key('esc', wait_screen_change => 1);
        # in some verification tests this didn't work, so let's check
        if (!check_screen($mustmatch)) {
            record_info('Retry', "shift-f3 workaround did not solve the problem");
            send_key('alt-f10', wait_screen_change => 1);
            send_key('alt-f10', wait_screen_change => 1);
        }
    }
}

1;
