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
use feature 'state';
use testapi;
use JSON qw(decode_json);
use utils qw(clear_console show_oom_info remount_tmp_if_ro detect_bsc_1063638 download_script);
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
  record_avc_selinux_alerts
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
    script_run("$cmd | tee $file", timeout => $args->{timeout});
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
    my $cmp = defined($args->{gzip}) ? '-zcv' : '-jcv';
    script_run("tar $cmp -f $dest $sources", $args->{timeout});
    upload_logs($dest, failok => 1) unless $args->{noupload};
    save_screenshot() if $args->{screenshot};
}

=head2 save_and_upload_systemd_unit_log

 save_and_upload_systemd_unit_log($unit);

Saves the journal of the systemd unit C<$unit> to C<journal_$unit.txt> and uploads it to openQA.

=cut

sub save_and_upload_systemd_unit_log {
    my ($self, $unit) = @_;
    $self->save_and_upload_log("journalctl --no-pager -u $unit -o short-precise", "journal_$unit.txt");
}

=head2

save_ulog($out $filename);

Creates a file from a string, the file is then saved in the ulogs directory of the worker running isotovideo. 
This is particularily useful when the SUT has no network connection.

example: 

$out = script_output('journalctl --no-pager -axb -o short-precise');
$filename = "my-test.txt";

=cut

sub save_ulog {
    my ($out, $filename) = @_;
    mkdir('ulogs') if (!-d 'ulogs');
    path("ulogs/$filename")->spew($out);    # save the logs to the ulogs directory on the worker directly
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
echo -e "\ndf -h" >> $health_log_file
df -h >> $health_log_file
echo -e "\ndf -i" >> $health_log_file
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
        script_run("coredumpctl info --no-pager | tee coredump-info.txt");
        upload_logs("coredump-info.txt", failok => $args{proceed_on_failure});
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
    save_and_upload_log("ip addr show", "/tmp/ip-addr-show.txt");
    save_and_upload_log("cat /etc/resolv.conf", "/tmp/resolv-conf.txt");

    export_logs_desktop();

    save_and_upload_log('systemctl list-unit-files', '/tmp/systemctl_unit-files.txt');
    save_and_upload_log('systemctl status', '/tmp/systemctl_status.txt');
    save_and_upload_log('systemctl', '/tmp/systemctl.txt', {screenshot => 1});

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
    save_and_upload_log("find /* -name '*.rpmnew'", "unapplied-configuration-files.txt", {screenshot => 1, noupload => 1, timeout => 300});
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
    if (script_run('which coredumpctl') == 0) {
        record_info('COREDUMP detection: ', script_output('coredumpctl list', proceed_on_failure => 1));
        save_and_upload_log("coredumpctl info", "segmentation-faults-info.txt", {screenshot => 1, noupload => 1});
        # Save core dumps
        enter_cmd "mkdir -p coredumps";
        enter_cmd 'awk \'/Storage|Coredump/{printf("cp %s ./coredumps/\n",$2)}\' segmentation-faults-info.txt | sh';
        clear_console;
    }

    # Broken links
    save_and_upload_log(
"find / -type d \\( -path /proc -o -path /run -o -path /.snapshots -o -path /var \\) -prune -o -xtype l -exec ls -l --color=always {} \\; -exec rpmquery -f {} \\;",
        "broken-symlinks.txt",
        {screenshot => 1, noupload => 1, timeout => 300});
    clear_console;

    # Binaries with missing libraries
    download_script('lib/missing_libraries.sh', '/tmp/missing_libraries.sh');
    save_and_upload_log("/tmp/missing_libraries.sh",
        "binaries-with-missing-libraries.txt", {timeout => 60, noupload => 1});
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

    # Mounts
    save_and_upload_log("findmnt -o TARGET,SOURCE,FSTYPE,VFS-OPTIONS,FS-OPTIONS,PROPAGATION", "findmnt.txt", {screenshot => 1, noupload => 1});

    # Snapper info
    save_and_upload_log("snapper --no-dbus list --disable-used-space", "snapper-list.txt", {screenshot => 1, noupload => 1});

    # Include generally useful log files as-is. Nonexisting files will be ignored.
    my @logs = qw(/var/log/audit/audit.log /var/log/snapper.log /var/log/transactional-update.log
      /var/log/zypper.log /var/log/zypp/history);

    script_run("cp -v --parents @logs .");

    script_run('tar cvvJf problem_detection_logs.tar.xz *');
    upload_logs('problem_detection_logs.tar.xz', failok => 1);
    enter_cmd("popd");

    # Upload small (< 64KiB) files in the ESP
    script_run('find /boot/efi -size -64k -type f -print0 | xargs -0 tar cavf esp-config.tar.gz');
    upload_logs('esp-config.tar.gz', failok => 1);

    # Upload BLS state as seen by bootctl
    save_and_upload_log("bootctl status; bootctl list", "bootctl.txt");
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
    save_and_upload_log('ps axf', '/tmp/psaxf.txt', {screenshot => 1});
    save_and_upload_log('journalctl -b -o short-precise', '/tmp/journal.txt', {screenshot => 1});
    save_and_upload_log('dmesg', '/tmp/dmesg.txt', {screenshot => 1});
    tar_and_upload_log('/etc/sysconfig', '/tmp/sysconfig.tar.gz', {gzip => 1});
    for my $service (get_started_systemd_services()) {
        save_and_upload_log("journalctl -b -u $service", "/tmp/journal_$service.txt", {screenshot => 1});
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
        save_and_upload_log("cat $log_path", '/tmp/Xlogs.system.txt', {screenshot => 1});
    }

    # do not upload empty .xsession-errors
    $log_path = '/home/*/.xsession-errors*';
    if (!script_run("ls -l $log_path")) {
        save_and_upload_log("cat $log_path", '/tmp/xsession-errors.txt', {screenshot => 1});
    }
    $log_path = '/home/*/.local/share/sddm/*session.txt';
    if (!script_run("ls -l $log_path")) {
        save_and_upload_log("cat $log_path", '/tmp/sddm_session.txt', {screenshot => 1});
    }
}

# I am not sure if this should even be here
my %avc_record = (
    start => 0,
    end => undef
);

sub _avc_products_apply {
    my ($products) = @_;

    return 1 if !defined $products;

    my $distri = get_required_var('DISTRI');
    my $version = get_required_var('VERSION');
    my $arch = get_required_var('ARCH');

    if (exists $products->{distri}) {
        my %allow = map { $_ => 1 } @{$products->{distri}};
        return 0 if !$allow{$distri};
    }

    if (exists $products->{version}) {
        my %allow = map { $_ => 1 } @{$products->{version}};
        return 0 if !$allow{$version};
    }

    if (exists $products->{arch}) {
        my %allow = map { $_ => 1 } @{$products->{arch}};
        return 0 if !$allow{$arch};
    }

    return 1;
}

sub _avc_ctx_match {
    my ($want, $got, $mode) = @_;
    $want //= '';
    $got //= '';
    $mode //= 'exact';

    return 0 if $want eq '';

    return ($want eq $got) if $mode eq 'exact';

    if ($mode eq 'prefix') {
        my $want_colons = ($want =~ tr/:/:/);
        if ($want_colons < 3) {
            return ($got eq $want) || (index($got, $want . ':') == 0);
        }
        return ($want eq $got);
    }

    return ($want eq $got);
}

sub _avc_parse_line {
    my ($ln) = @_;
    my @events;

    return \@events if !defined $ln;
    return \@events if $ln !~ /\bavc:\s+denied\b/i;

    my ($perm_blob) = $ln =~ /\{\s*([^}]+?)\s*\}/;
    my ($scontext) = $ln =~ /\bscontext=([^\s]+)/;
    my ($tcontext) = $ln =~ /\btcontext=([^\s]+)/;
    my ($tclass) = $ln =~ /\btclass=([^\s]+)/;

    return \@events if !$perm_blob || !$scontext || !$tcontext || !$tclass;

    my @perms = grep { length($_) } split(/\s+/, $perm_blob);
    for my $p (@perms) {
        push @events, {
            permission => $p,
            scontext => $scontext,
            tcontext => $tcontext,
            tclass => $tclass,
        };
    }

    return \@events;
}

sub _load_avc_whitelist {
    state $cached;
    return $cached if defined $cached;

    my $file = sprintf(
        "%s/data/avc_check/avc_whitelist.json",
        get_var('CASEDIR')
    );

    open(my $fh, '<', $file)
      or die "Can't open AVC whitelist '$file': $!";

    local $/ = undef;
    my $json = <$fh>;
    close $fh;

    my $whitelist = decode_json($json);
    return $cached = $whitelist;
}

sub _avc_is_permitted {
    my ($ev, $whitelist) = @_;

    for my $entry (@$whitelist) {
        if (exists $entry->{products}) {
            next if !_avc_products_apply($entry->{products});
        }

        next if ($entry->{permission} // '') ne ($ev->{permission} // '');

        my $mode = $entry->{match}->{context_mode} // 'exact';

        next if !_avc_ctx_match($entry->{scontext}, $ev->{scontext}, $mode);

        if (exists $entry->{tcontext}) {
            next if !_avc_ctx_match($entry->{tcontext}, $ev->{tcontext}, $mode);
        }

        if (exists $entry->{tclass}) {
            next if ($entry->{tclass} // '') ne ($ev->{tclass} // '');
        }

        return 1;
    }

    return 0;
}

=head2 record_avc_selinux_alerts

List AVCs that have been recorded during a runtime of a test module that executes this function

=cut

sub record_avc_selinux_alerts {
    my $self = shift;

    return if (current_console() !~ /root|log/);
    return if (script_run('test -d /sys/fs/selinux') != 0);

    my @logged = split(/\n/, script_output('ausearch -m avc,user_avc,selinux_err,user_selinux_err -r',
            timeout => 300, proceed_on_failure => 1));

    if (scalar @logged <= $avc_record{start}) {
        record_info('AVC', 'No AVCs were recorded');
        return;
    }

    $avc_record{end} = scalar @logged - 1;
    my @avc = @logged[$avc_record{start} .. $avc_record{end}];
    $avc_record{start} = $avc_record{end} + 1;

    return if !@avc;

    my $whitelist = _load_avc_whitelist();

    my (@permitted_raw, @unpermitted_raw);

    for my $ln (@avc) {
        my $events = _avc_parse_line($ln);

        if (!@$events) {
            push @unpermitted_raw, $ln;
            next;
        }

        my $all_permitted = 1;
        for my $ev (@$events) {
            if (!_avc_is_permitted($ev, $whitelist)) {
                $all_permitted = 0;
                last;
            }
        }

        if ($all_permitted) {
            push @permitted_raw, $ln;
        } else {
            push @unpermitted_raw, $ln;
        }
    }

    if (@unpermitted_raw) {
        my $fail_on_denials = get_var('AVC_FAIL_ON_DENIALS', 0);

        my $result = $fail_on_denials ? 'fail' : 'softfails';
        record_info('AVC (unpermitted)', join("\n", @unpermitted_raw), result => $result);

        if ($fail_on_denials && ($self->{post_fail_hook_running} == 0)) {
            $self->result('fail');
        }
    }
}

1;
