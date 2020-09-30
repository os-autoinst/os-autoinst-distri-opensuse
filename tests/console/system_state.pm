# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
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
#
# Summary:  Export the existing status of running tasks and system load
# for future reference
# - Collect running process list
# - Collect system load average
# - Upload the gatherings to the job's logs
# Maintainer: Zaoliang Luo <zluo@suse.de>

use base "consoletest";
use testapi;
use utils;
use Utils::Backends 'use_ssh_serial_console';
use strict;
use warnings;

sub run {
    my ($self) = shift;
    check_var("BACKEND", "ipmi") ? use_ssh_serial_console : select_console 'root-console';
    script_run "mkdir /tmp/system_state";
    script_run "ps axf > /tmp/system_state/psaxf.log";
    script_run "cat /proc/loadavg > /tmp/system_state/loadavg_consoletest_setup.txt";
    $self->tar_and_upload_log('/tmp/system_state', '/tmp/stats_during_installation.tar.bz2');
}

1;
