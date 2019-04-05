package consoletest;
use base "opensusebasetest";

use strict;
use warnings;
use testapi;
use known_bugs;

# Base class for all console tests

sub post_run_hook {
    my ($self) = @_;

    # start next test in home directory
    type_string "cd\n";

    # clear screen to make screen content ready for next test
    $self->clear_and_verify_console;
}

sub post_fail_hook {
    my ($self) = shift;
    select_console('log-console');
    $self->SUPER::post_fail_hook;
    $self->remount_tmp_if_ro;
    # Export logs after failure
    assert_script_run("journalctl --no-pager -b 0 > /tmp/full_journal.log");
    upload_journal "/tmp/full_journal.log";
    assert_script_run("dmesg > /tmp/dmesg.log");
    upload_logs "/tmp/dmesg.log";
    # Export extra log after failure for further check gdm issue 1127317, also poo#45236 used for tracking action on Openqa
    script_run("tar -jcv -f /tmp/xorg.tar.bz2  /home/bernhard/.local/share/xorg");
    upload_logs('/tmp/xorg.tar.bz2', failok => 1);
    script_run("tar -jcv -f /tmp/sysconfig.tar.bz2  /etc/sysconfig");
    upload_logs('/tmp/sysconfig.tar.bz2', failok => 1);
    script_run("tar -jcv -f /tmp/gdm.tar.bz2  /home/bernhard/.cache/gdm");
    upload_logs('/tmp/gdm.tar.bz2', failok => 1);
}

1;
