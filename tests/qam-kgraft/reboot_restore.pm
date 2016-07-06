# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.#


use base 'opensusebasetest';
use testapi;
use qam;

use strict;
use warnings;

sub mod_rpm_info {
    my $module = shift;
    script_run("rpm -qf /$module");
    save_screenshot;
    script_run("modinfo /$module");
    save_screenshot;
}

sub run() {
    my $self           = shift;
    my $svirt          = select_console('svirt');
    my $name           = get_var('VIRSH_GUESTNAME');
    my $snapshot_after = get_var('KGRAFT_SNAPSHOT_AFTER');
    my $rrid           = get_var('MAINT_UPDATE_RRID');
    my $ret            = 1;
    $svirt->attach_to_running($name);

    reset_consoles;
    select_console('sut');
    wait_serial(qr/Welcome to SUSE Linux Enterprise Server /, 240);
    select_console('root-console');

    check_automounter;

    while ($ret) {
        script_run("clear");
        script_run(qq{/usr/share/qa/tools/remote_qa_db_report.pl -b -T openqa -c "`uname -r -v`" -t patch:"$rrid"; echo submission-\$?- > /dev/$serialdev}, 0);
        if (check_screen('submission-failed')) {
            script_run("ssh-keygen -R qadb2.suse.de -f /root/.ssh/known_hosts");
            next;
        }
        ($ret) = wait_serial(qr/submission-(\d+)-/, 1800) =~ qr/-(\d+)/;
    }
    save_screenshot;

    script_run("journalctl --boot=-1 > /tmp/journal_before", 0);
    sleep 10;
    upload_logs("/tmp/journal_before");
    capture_state("after_ltp");

    script_run("ls -lt /boot >/tmp/lsboot");
    upload_logs("/tmp/lsboot");
    script_run("cat /tmp/lsboot");
    save_screenshot;

    script_run("basename /boot/initrd-\$(uname -r) | sed s_initrd-__g | sed s_-default__g | tee > /dev/$serialdev", 0);
    my ($kver) = wait_serial(qr/^\d\.\d+\.\d+-\d+\.\d+/) =~ /(^\d\.\d+\.\d+-\d+\.\d+)\s/;

    script_run("lsinitrd /boot/initrd-$kver-xen | grep patch");
    save_screenshot;
    script_run("lsinitrd /boot/initrd-$kver-xen | awk '/-patch-.*ko\$/ {print \$NF}' > /dev/$serialdev", 0);
    my ($module) = wait_serial(qr/lib*/) =~ /(^.*ko)\s+/;

    mod_rpm_info($module);

    script_run("lsinitrd /boot/initrd-$kver-default | grep patch");
    save_screenshot;
    script_run("lsinitrd /boot/initrd-$kver-default | awk '/-patch-.*ko\$/ {print \$NF}' > /dev/$serialdev", 0);
    ($module) = wait_serial(qr/lib*/) =~ /(^.*ko)\s+/;

    mod_rpm_info($module);

    my $ret_snap = $svirt->run_cmd("virsh snapshot-revert $name $snapshot_after --running");
    die "Snapshot $snapshot_after failed" if $ret_snap;

    script_run("uname -a");
    save_screenshot;
    type_string("logout\n");
}

sub post_fail_hook() {
    my $self            = shift;
    my $snapshot_before = get_var('KGRAFT_SNAPSHOT_BEFORE');
    my $name            = get_var('VIRSH_GUESTNAME');
    save_screenshot;
    send_key('ctrl-c');
    sleep 2;
    capture_state("fail");

    #reconnect to svirt backend and revert to snapshot before update
    my $svirt = select_console('svirt');
    $svirt->attach_to_running($name);
    my $ret = $svirt->run_cmd("virsh snapshot-revert $name $snapshot_before --running");
    die "Snapshot $snapshot_before failed" if $ret;

}

sub test_flags() {
    return {fatal => 1};
}

1;
