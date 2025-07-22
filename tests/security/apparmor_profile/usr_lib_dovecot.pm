# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: apparmor-utils apparmor-parser dovecot
# Summary: Test with "usr.lib.dovecot.*" (mainly *.(imap|pop3)*) & "usr.sbin.dovecot"
#          are in "enforce" mode retrieve mails with imap & pop3 should have no error.
# - Start apparmor service
# - Run "aa-enforce usr.sbin.dovecot" and check output for enforce mode is set
# - Run "aa-enforce /etc/apparmor.d/usr.lib.dovecot*" and check output for enforce mode is set
# - Run aa-status and confirm that "usr.lib.dovecot.imap is on enforce mode
# - Restart dovecot
# - Use telnet and retrieve email using imap
# - Check audit.log for existence of errors related to dovecot

# Maintainer: QE Security <none@suse.de>
# Tags: poo#46235, tc#1695943, poo#46238, tc#1695947

use base "apparmortest";
use testapi;
use utils;
use serial_terminal qw(select_serial_terminal);

sub run {
    my ($self) = shift;

    my $audit_log = $apparmortest::audit_log;
    my $mail_err_log = $apparmortest::mail_err_log;
    my $mail_warn_log = $apparmortest::mail_warn_log;
    my $mail_info_log = $apparmortest::mail_info_log;
    my $profile_name = "";
    my $named_profile = "";

    # Start apparmor
    systemctl("start apparmor");

    # Set the AppArmor security profile to enforce mode
    $profile_name = "usr.lib.dovecot.*";
    validate_script_output("aa-enforce /etc/apparmor.d/$profile_name", sub { m/Setting .*$profile_name to enforce mode./ });

    $profile_name = "usr.sbin.dovecot";
    validate_script_output("aa-enforce $profile_name", sub { m/Setting .*$profile_name to enforce mode./ });

    for my $protocol (qw(imap pop3)) {
        # Recalculate profile name in case
        $profile_name = "usr.lib.dovecot.$protocol";
        $named_profile = $self->get_named_profile($profile_name);
        # Check if $profile_name is in "enforce" mode
        $self->aa_status_stdout_check($named_profile, "enforce");

        # Restart Dovecot
        systemctl("restart dovecot");
        sleep 3;

        # cleanup audit log
        assert_script_run("echo > $audit_log");
        # cleanup mail logs
        assert_script_run("echo > $mail_err_log");
        assert_script_run("echo > $mail_warn_log");
        assert_script_run("echo > $mail_info_log");

        # Retrieve email with a $protocol account
        select_console('root-console');
        my $retrieve = "retrieve_mail_$protocol";
        $self->$retrieve;
        select_serial_terminal;
    }

    # Verify audit log contains no related error
    my $script_output = script_output "cat $audit_log";
    if ($script_output =~ m/type=AVC .*apparmor=.*DENIED.* profile=.*dovecot.*/sx) {
        record_info("ERROR", "There are errors found in $audit_log", result => 'fail');
        $self->result('fail');
    }

    # Verify mail log contains no related error
    $script_output = script_output "cat $mail_err_log";
    if ($script_output =~ m/.*dovecot: .* Error: .*/sx) {
        record_info("ERROR", "There are errors found in $mail_err_log", result => 'fail');
        $self->result('fail');
    }

    # Upload mail logs for reference
    $self->upload_logs_mail();
}

1;
