# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
# Summary: All the logging related subroutines
# Maintainer: Pavel Dostál <pdostal@suse.cz>, QE Core <qe-core@suse.com>

=head1 Utils::Logging

C<Utils::Logging> - Save logs directly on the worker for offline upload via ulogs 

=cut

package Utils::Logging;

use base 'Exporter';
use Exporter;
use strict;
use warnings;
use testapi;
use utils qw(clear_console show_oom_info remount_tmp_if_ro detect_bsc_1063638);
use Utils::Systemd 'get_started_systemd_services';
use Mojo::File 'path';
use serial_terminal 'select_serial_terminal';

our @EXPORT = qw(
  save_and_upload_log
  tar_and_upload_log
  save_and_upload_systemd_unit_log
  save_ulog
  export_healthcheck_basic
  select_log_console
  upload_coredumps
  export_logs
  problem_detection
  upload_solvertestcase_logs
  export_logs_basic
  export_logs_desktop
);

=head2 save_and_upload_log

 save_and_upload_log($cmd, $file [, timeout => $timeout] [, screenshot => $screenshot] [, noupload => $noupload]);

Will run C<$cmd> on the SUT (without caring for the return code) and tee the standard output to a file called C<$file>.
The C<$timeout> parameter specifies how long C<$cmd> may run.
When C<$cmd> returns, the output file will be uploaded to openQA unless C<$noupload> is set.
Afterwards a screenshot will be created if C<$screenshot> is set.
=cut

sub save_and_upload_log {
    my ($cmd, $file, $args) = @_;
    script_run("$cmd | tee $file", $args->{timeout});
    my $lname = $args->{logname} ? $args->{logname} : '';
    upload_logs($file, failok => 1, log_name => $lname) unless $args->{noupload};
    save_screenshot if $args->{screenshot};
}

=head2 tar_and_upload_log

 tar_and_upload_log($sources, $dest, [, timeout => $timeout] [, screenshot => $screenshot] [, noupload => $noupload]);

Will create an xz compressed tar archive with filename C<$dest> from the folder(s) listed in C<$sources>.
The return code of C<tar> will be ignored.
The C<$timeout> parameter specifies how long C<tar> may run.
When C<tar> returns, the output file will be uploaded to openQA unless C<$noupload> is set.
Afterwards a screenshot will be created if C<$screenshot> is set.

=cut

sub tar_and_upload_log {
    my ($sources, $dest, $args) = @_;
    script_run("tar -jcv -f $dest $sources", $args->{timeout});
    upload_logs($dest, failok => 1) unless $args->{noupload};
    save_screenshot() if $args->{screenshot};
}

=head2 save_and_upload_systemd_unit_log

 save_and_upload_systemd_unit_log($unit);

Saves the journal of the systemd unit C<$unit> to C<journal_$unit.log> and uploads it to openQA.

=cut

sub save_and_upload_systemd_unit_log {
    my ($self, $unit) = @_;
    $self->save_and_upload_log("journalctl --no-pager -u $unit -o short-precise", "journal_$unit.log");
}

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

=head2 export_healthcheck_basic

 export_healthcheck_basic();

Upload healthcheck logs that make sense for any failure.
This includes C<cpu>, C<memory> and C<fdisk>.

=cut

sub export_healthcheck_basic {

    my $cmd = <<'EOF';
health_log_file="/tmp/basic_health_check.txt"
echo -e "free -h" > $health_log_file
free -h >> $health_log_file
echo -e "\nvmstat" >> $health_log_file
vmstat >> $health_log_file
echo -e "\nfdisk -l" >> $health_log_file
fdisk -l >> $health_log_file
echo -e "\ndh -h" >> $health_log_file
df -h >> $health_log_file
echo -e "\ndh -i" >> $health_log_file
df -i >> $health_log_file
echo -e "\nTop 10 CPU Processes" >> $health_log_file
ps axwwo %cpu,pid,user,cmd | sort -k 1 -r -n | head -11 | sed -e '/^%/d' >> $health_log_file
echo -e "\nTop 10 Memory Processes" >> $health_log_file
ps axwwo %mem,pid,user,cmd | sort -k 1 -r -n | head -11 | sed -e '/^%/d' >> $health_log_file
echo -e "\nALL Processes" >> $health_log_file
ps axwwo user,pid,ppid,%cpu,%mem,vsz,rss,stat,time,cmd >> $health_log_file
EOF
    script_run($_) foreach (split /\n/, $cmd);
    upload_logs "/tmp/basic_health_check.txt";

}

=head2 select_log_console

 select_log_console();

Select 'log-console' with higher timeout on screen check to even cover systems
that react very slow due to high background load or high memory consumption.
This should be especially useful in C<post_fail_hook> implementations.

=cut

sub select_log_console { select_console('log-console', timeout => 180, @_) }

=head2 upload_coredumps

 upload_coredumps(%args);

Upload all coredumps to logs. In case `proceed_on_failure` key is set to true,
errors during logs collection will be ignored, which is usefull for the
post_fail_hook calls.
=cut

sub upload_coredumps {
    my (%args) = @_;
    my $res = script_run('coredumpctl --no-pager');
    if (!$res) {
        record_info("COREDUMPS found", "we found coredumps on SUT, attemp to upload");
        script_run("coredumpctl info --no-pager | tee coredump-info.log");
        upload_logs("coredump-info.log", failok => $args{proceed_on_failure});
        my $basedir = '/var/lib/systemd/coredump/';
        my @files = split("\n", script_output("\\ls -1 $basedir | cat", proceed_on_failure => $args{proceed_on_failure}));
        foreach my $file (@files) {
            upload_logs($basedir . $file, failok => $args{proceed_on_failure});
        }
    }
}

=head2 export_logs

 export_logs();

This method will call several other log gathering methods from this class.

=cut

sub export_logs {
    select_serial_terminal();
    remount_tmp_if_ro();
    export_logs_basic();
    problem_detection();

    # Just after the setup: let's see the network configuration
    save_and_upload_log("ip addr show", "/tmp/ip-addr-show.log");
    save_and_upload_log("cat /etc/resolv.conf", "/tmp/resolv-conf.log");

    export_logs_desktop();

    save_and_upload_log('systemctl list-unit-files', '/tmp/systemctl_unit-files.log');
    save_and_upload_log('systemctl status', '/tmp/systemctl_status.log');
    save_and_upload_log('systemctl', '/tmp/systemctl.log', {screenshot => 1});

    if ($utils::IN_ZYPPER_CALL) {
        upload_solvertestcase_logs();
    }
}

=head2 problem_detection

 problem_detection();

This method will upload a number of logs and debugging information.
This includes a log with all journal errors, a systemd unit plot and the
output of rpmverify.
The files will be uploaded as a single tarball called C<problem_detection_logs.tar.xz>.

=cut

sub problem_detection {
    enter_cmd "pushd \$(mktemp -d)";
    detect_bsc_1063638;
    # Slowest services
    save_and_upload_log("systemd-analyze blame", "systemd-analyze-blame.txt", {noupload => 1});
    clear_console;

    # Generate and upload SVG out of `systemd-analyze plot'
    save_and_upload_log('systemd-analyze plot', "systemd-analyze-plot.svg", {noupload => 1});
    clear_console;

    # Failed system services
    save_and_upload_log('systemctl --all --state=failed', "failed-system-services.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Unapplied configuration files
    save_and_upload_log("find /* -name '*.rpmnew'", "unapplied-configuration-files.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Errors, warnings, exceptions, and crashes mentioned in dmesg
    save_and_upload_log("dmesg | grep -i 'error\\|warn\\|exception\\|crash'", "dmesg-errors.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Errors in journal
    save_and_upload_log("journalctl --no-pager -p 'err' -o short-precise", "journalctl-errors.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Tracebacks in journal
    save_and_upload_log('journalctl -o short-precise | grep -i traceback', "journalctl-tracebacks.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Segmentation faults
    save_and_upload_log("coredumpctl list", "segmentation-faults-list.txt", {screenshot => 1, noupload => 1});
    save_and_upload_log("coredumpctl info", "segmentation-faults-info.txt", {screenshot => 1, noupload => 1});
    # Save core dumps
    enter_cmd "mkdir -p coredumps";
    enter_cmd 'awk \'/Storage|Coredump/{printf("cp %s ./coredumps/\n",$2)}\' segmentation-faults-info.txt | sh';
    clear_console;

    # Broken links
    save_and_upload_log(
"find / -type d \\( -path /proc -o -path /run -o -path /.snapshots -o -path /var \\) -prune -o -xtype l -exec ls -l --color=always {} \\; -exec rpmquery -f {} \\;",
        "broken-symlinks.txt",
        {screenshot => 1, noupload => 1, timeout => 60});
    clear_console;

    # Binaries with missing libraries
    save_and_upload_log("
IFS=:
for path in \$PATH; do
    for bin in \$path/*; do
        ldd \$bin 2> /dev/null | grep 'not found' && echo -n Affected binary: \$bin 'from ' && rpmquery -f \$bin
    done
done", "binaries-with-missing-libraries.txt", {timeout => 60, noupload => 1});
    clear_console;

    # rpmverify problems
    save_and_upload_log("rpmverify -a | grep -v \"[S5T].* c \"", "rpmverify-problems.txt", {timeout => 1200, screenshot => 1, noupload => 1});
    clear_console;

    # VMware specific
    if (check_var('VIRSH_VMM_FAMILY', 'vmware')) {
        script_run('vm-support');
        upload_logs('vm-*.*.tar.gz', failok => 1);
        clear_console;
    }

    script_run 'tar cvvJf problem_detection_logs.tar.xz *';
    upload_logs('problem_detection_logs.tar.xz', failok => 1);
    enter_cmd "popd";
}

=head2 upload_solvertestcase_logs

 upload_solvertestcase_logs();

Upload C</tmp/solverTestCase.tar.bz2>.

=cut

sub upload_solvertestcase_logs {
    my $ret = script_run("zypper -n patch --debug-solver --with-interactive -l");
    # if zypper was not found, we just skip upload solverTestCase.tar.bz2
    return if $ret != 0;
    script_run("tar -cvjf /tmp/solverTestCase.tar.bz2 /var/log/zypper.solverTestCase/*");
    upload_logs "/tmp/solverTestCase.tar.bz2 ";
}

=head2 export_logs_basic

 export_logs_basic();

Upload logs that make sense for any failure.
This includes C</proc/loadavg>, C<ps axf>, complete journal since last boot, C<dmesg> and C</etc/sysconfig>.

=cut

sub export_logs_basic {
    save_and_upload_log('cat /proc/loadavg', '/tmp/loadavg.txt', {screenshot => 1});
    save_and_upload_log('ps axf', '/tmp/psaxf.log', {screenshot => 1});
    save_and_upload_log('journalctl -b -o short-precise', '/tmp/journal.log', {screenshot => 1});
    save_and_upload_log('dmesg', '/tmp/dmesg.log', {screenshot => 1});
    tar_and_upload_log('/etc/sysconfig', '/tmp/sysconfig.tar.bz2');

    for my $service (get_started_systemd_services()) {
        save_and_upload_log("journalctl -b -u $service", "/tmp/journal_$service.log", {screenshot => 1});
    }
}

=head2 export_logs_desktop

 export_logs_desktop();

Upload several KDE, GNOME, X11, GDM and SDDM related logs and configs.

=cut

sub export_logs_desktop {
    select_serial_terminal();

    if (check_var("DESKTOP", "kde")) {
        if (get_var('PLASMA5')) {
            tar_and_upload_log("/home/$username/.config/*rc", '/tmp/plasma5_configs.tar.bz2');
        }
        else {
            tar_and_upload_log("/home/$username/.kde4/share/config/*rc", '/tmp/kde4_configs.tar.bz2');
        }
        #save_screenshot;
    } elsif (check_var("DESKTOP", "gnome")) {
        tar_and_upload_log("/home/$username/.cache/gdm", '/tmp/gdm.tar.bz2');
    }

    # check whether xorg logs exist in user's home, if yes, upload xorg logs
    # from user's home instead of /var/log
    my $log_path = '/home/*/.local/share/xorg/';
    if (!script_run("test -d $log_path")) {
        tar_and_upload_log("$log_path", '/tmp/Xlogs.users.tar.bz2', {screenshot => 1});
    }
    $log_path = '/var/log/X*';
    if (!script_run("ls -l $log_path")) {
        save_and_upload_log("cat $log_path", '/tmp/Xlogs.system.log', {screenshot => 1});
    }

    # do not upload empty .xsession-errors
    $log_path = '/home/*/.xsession-errors*';
    if (!script_run("ls -l $log_path")) {
        save_and_upload_log("cat $log_path", '/tmp/xsession-errors.log', {screenshot => 1});
    }
    $log_path = '/home/*/.local/share/sddm/*session.log';
    if (!script_run("ls -l $log_path")) {
        save_and_upload_log("cat $log_path", '/tmp/sddm_session.log', {screenshot => 1});
    }
}

1;
