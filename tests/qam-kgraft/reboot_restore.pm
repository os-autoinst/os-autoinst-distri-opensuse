# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.#

# Summary: Live Patching regression testsuite
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use base 'kgrafttest';
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
    my $svirt          = select_console('svirt');
    my $name           = get_var('VIRSH_GUESTNAME');
    my $snapshot_after = get_var('KGRAFT_SNAPSHOT_AFTER');
    my $rrid           = get_var('MAINT_UPDATE_RRID');
    $svirt->attach_to_running($name);

    reset_consoles;
    select_console('sut');
    wait_serial(qr/Welcome to SUSE Linux Enterprise Server /, 240);
    select_console('root-console');

    check_automounter;

    #TODO: move to openQA data folder
    assert_script_run("curl -f " . autoinst_url . "/data/qam/fcsf.sh -o /tmp/fcsf.sh");
    assert_script_run("chmod a+x /tmp/fcsf.sh");
    script_run("/tmp/fcsf.sh -il -P /var/log/qa/ctcs2 -r openposix", 60);

    assert_script_run("tar -cpzf /tmp/var_log_qa_ctcs2.tar.gz -C / /var/log/qa/ctcs2", 120);
    upload_logs("/tmp/var_log_qa_ctcs2.tar.gz");

    script_run("ssh-keygen -R qadb2.suse.de");
    assert_script_run(
        qq{/usr/share/qa/tools/remote_qa_db_report.pl \\
                         -L \\
                         -b \\
                         -T openqa \\
                         -c "`uname -r -v` `kgr -v patches | grep -B2 RPM | head -n1`" \\
                         -t patch:"$rrid" \\
                         &> /tmp/submission.log }, 1800
    );
    script_run("cat /tmp/submission.log");
    save_screenshot;
    script_run(q{grep -o -E 'http:\/{2}.*\/submission\.php\?submission_id=[0-9]+' /tmp/submission.log > /tmp/submission_url.log});
    upload_logs('/tmp/submission_url.log');
    upload_logs('/tmp/submission.log');

    script_run("journalctl --boot=-1 > /tmp/journal_before", 0);
    sleep 10;
    upload_logs("/tmp/journal_before");
    capture_state("after_ltp");

    script_run("ls -lt /boot >/tmp/lsboot");
    upload_logs("/tmp/lsboot");
    script_run("cat /tmp/lsboot");
    save_screenshot;

    script_run("basename /boot/initrd-\$(uname -r) | sed s_initrd-__g > /dev/$serialdev", 0);
    my ($kver) = wait_serial(qr/(^[\d.-]+)-.+\s/) =~ /(^[\d.-]+)-.+\s/;

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

    script_run("uname -a");
    save_screenshot;

    snap_revert($svirt, $name, $snapshot_after);
}

1;
