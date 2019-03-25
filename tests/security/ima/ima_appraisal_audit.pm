# Copyright (C) 2019 SUSE LLC
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
# Summary: Test audit function for IMA appraisal
# Note: This case should come after 'ima_appraisal_digital_signatures'
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Tags: poo#49568

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use bootloader_setup qw(add_grub_cmdline_settings replace_grub_cmdline_settings);
use power_action_utils "power_action";

sub audit_verify {
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $sample_app = '/usr/bin/yes';
    my $sample_cmd = 'yes --version';

    systemctl('is-active auditd');

    # Make sure IMA is in the enforce mode
    validate_script_output "grep -E 'ima_appraise=(fix|log|off)' /etc/default/grub || echo 'IMA enforced'", sub { m/IMA enforced/ };
    assert_script_run("test -e /etc/sysconfig/ima-policy", fail_message => 'ima-policy file is missing');

    # Clear security.ima no matter whether it existing
    script_run "setfattr -x security.ima $sample_app";
    validate_script_output "getfattr -m security.ima -d $sample_app", sub { m/^$/ };

    assert_script_run("echo -n '' > /var/log/audit/audit.log");
    my $ret = script_output($sample_cmd, 30, proceed_on_failure => 1);
    die "$sample_app should not have permission to run" if ($ret !~ "\Q$sample_app\E: *Permission denied");
    validate_script_output "ausearch -m INTEGRITY_DATA", sub { m/\Q$sample_app\E/ };

    # Test both default(no ima_apprais=) and ima_appraise=log situation
    add_grub_cmdline_settings("ima_appraise=log", 1);
    power_action('reboot', textmode => 1);
    $self->wait_boot(textmode => 1);
    $self->select_serial_terminal;

    assert_script_run("echo -n '' > /var/log/audit/audit.log");
    assert_script_run "$sample_cmd";
    validate_script_output "ausearch -m INTEGRITY_DATA", sub { m/\Q$sample_app\E/ };
}

sub test_flags {
    return {always_rollback => 1};
}

1;
