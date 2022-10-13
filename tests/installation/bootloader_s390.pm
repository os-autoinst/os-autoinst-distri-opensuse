# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Start the installation process on s390x zVM using the z3270
#   terminal and an ssh connection
# Maintainer: Matthias Griessmeier <mgriessmeier@suse.de>


package bootloader_s390;

use base "installbasetest";

use testapi;

use strict;
use warnings;
use English;

use bootloader_setup;
use registration;
use utils 'shorten_url';
use version_utils qw(is_sle is_tumbleweed);

# try to find the 2 longest lines that are below beyond the limit
# collapsing the lines - we have a limit of 10 lines
sub try_merge_lines {
    my ($lines, $columns) = @_;
    # the order of the parameters doesn't matter, so take the longest first
    @$lines = sort { length($b) <=> length($a) } @$lines;
    for my $start_index (0 .. scalar(@$lines) - 1) {
        my $start = $lines->[$start_index];
        for my $end_index ($start_index + 1 .. scalar(@$lines) - 1) {
            my $end = $lines->[$end_index];
            if (length($start) + length($end) + 1 < $columns) {    # hit!
                my $last = pop @$lines;
                $lines->[$start_index] .= " $end";
                $lines->[$end_index] = $last unless ($last eq $end);
                return 1;
            }
        }
    }
    return 0;
}

sub split_lines {
    my ($params) = @_;

    # s3270 has a funny behaviour in xedit, so be careful
    my $columns = 72;

    my @lines = split(/ /, $params);
    while (try_merge_lines(\@lines, $columns)) {
        # just keep trying!
    }

    $params = '';
    for my $line (@lines) {
        $params .= "String(\"$line \")\nNewline\n";
    }

    return $params;
}

use backend::console_proxy;

sub create_infofile {
    my ($bootinfo) = @_;
    my $path = 's390x_bootinfo';
    save_tmp_file($path, $bootinfo);
    return shorten_url(autoinst_url . "/files/$path");
}

sub prepare_parmfile {
    my ($repo) = @_;
    my $params = '';
    $params .= " " . get_var('S390_NETWORK_PARAMS');
    $params .= " " . get_var('EXTRABOOTPARAMS');

    $params .= remote_install_bootmenu_params;

    # we have to hardcode the hostname here - the true hostname would
    # create a too long parameter ;(
    my $instsrc = get_var('INSTALL_SOURCE', 'ftp') . '://' . get_var('REPO_HOST', 'openqa') . '/';
    if (check_var('INSTALL_SOURCE', 'smb')) {
        $instsrc .= "inst/" . $repo;
        $params .= " info=" . create_infofile("install: $instsrc");
    }
    else {
        $params .= " install=" . $instsrc . $repo . " ";
    }

    if (get_var('UPGRADE')) {
        $params .= 'upgrade=1 ';
    }

    $params .= specific_bootmenu_params;
    $params .= registration_bootloader_cmdline if check_var('SCC_REGISTER', 'installation');

    # Pass autoyast parameter for s390x, shorten the url because of 72 columns limit in x3270 xedit
    # If 'AUTOYAST_PREPARE_PROFILE' is true, shorten url directly, otherwise shorten url with data_url method
    if (get_var('AUTOYAST')) {
        if (get_var('AUTOYAST_PREPARE_PROFILE')) {
            $params .= " autoyast=" . shorten_url(get_var('AUTOYAST'));
            set_var('AUTOYAST', shorten_url(get_var('AUTOYAST')));
        }
        else {
            $params .= " autoyast=" . shorten_url(data_url(get_var('AUTOYAST')));
            set_var('AUTOYAST', shorten_url(data_url(get_var('AUTOYAST'))));
        }
    }
    return split_lines($params);
}

sub get_to_yast {
    my $self = shift;
    my $s3270 = console('x3270');

    my $r;

    # qaboot
    my $dir_with_suse_ins = get_var('REPO_UPGRADE_BASE_0') ? get_required_var('REPO_UPGRADE_BASE_0') : get_required_var('REPO_0');
    my $repo_host = get_var('REPO_HOST', 'openqa.suse.de');

    my $parmfile_with_Newline_s = prepare_parmfile($dir_with_suse_ins);
    my $sequence = <<"EO_frickin_boot_parms";
${parmfile_with_Newline_s}
ENTER
ENTER
EO_frickin_boot_parms

    # arbitrary number of retries
    my $max_retries = 7;
    for (1 .. $max_retries) {
        eval {
            # ensure that we are in cms mode before executing qaboot
            $s3270->sequence_3270("String(\"#cp i cms\")", "ENTER", "ENTER", "ENTER", "ENTER",);
            $r = $s3270->expect_3270(output_delim => qr/CMS/, timeout => 20);
            $s3270->sequence_3270("String(\"qaboot $repo_host $dir_with_suse_ins\")", "ENTER", "Wait(InputField)",);
            # wait for qaboot dumping us into xedit. If this fails, probably the
            # download of kernel or initrd timed out and we retry
            $r = $s3270->expect_3270(buffer_ready => qr/X E D I T/, timeout => 60);
        };
        last unless ($@);
        diag "s3270 sequence failed: $@";
        diag "Maybe the network is busy. Retry: $_ of $max_retries";
    }
    die "Download of Kernel or Initrd took too long (with retries)" unless $r;

    $s3270->sequence_3270(qw( String(INPUT) ENTER ));

    $r = $s3270->expect_3270(buffer_ready => qr/Input-mode/);

    # can't use qw() because of space in commands...
    $s3270->sequence_3270(split /\n/, $sequence);

    $r = $s3270->expect_3270(buffer_ready => qr/X E D I T/);

    ## Remove the "manual=1" and the empty line at the end
    ## of the parmfile.

    ## HACK HACK HACK HACK this code just 'knows' there is
    ## an empty line and a single "manual=1" at the bottom
    ## of the ftpboot parmfile.  This may fail in obscure
    ## ways when that changes.
    $s3270->sequence_3270(qw(String(BOTTOM) ENTER String(DELETE) ENTER));
    $s3270->sequence_3270(qw(String(BOTTOM) ENTER String(DELETE) ENTER));

    $r = $s3270->expect_3270(buffer_ready => qr/X E D I T/);

    # save the parmfile.  ftpboot then starts the installation.
    $s3270->sequence_3270(qw( String(FILE) ENTER ));

    # linuxrc
    $r = $s3270->expect_3270(
        output_delim => qr/Loading Installation System/,
        timeout => 300
    ) || die "Installation system was not found";

    # set up display_mode for textinstall
    my $display_type;
    if (check_var("VIDEOMODE", "text")) {
        $display_type = "SSH";
    }
    elsif (check_var('VIDEOMODE', 'ssh-x')) {
        $display_type = "SSH-X";
    }
    # default install is VNC
    else {
        $display_type = "VNC";
    }

    my $output_delim
      = $display_type eq "SSH" || $display_type eq "SSH-X" ? qr/\Q***  run 'yast.ssh' to start the installation  ***\E/
      : $display_type eq "VNC" ? qr/\*\*\* Starting YaST(2|) \*\*\*/
      : die "unknown vars.json:DISPLAY->TYPE <$display_type>";

    $r = $s3270->expect_3270(
        output_delim => $output_delim,
        timeout => 300
    ) || die "Loading Installation system tooks too long";

}

sub show_debug {
    assert_script_run('ps auxf');
    assert_script_run('dmesg');
    # make the install-shell look like the ones on other systems where we
    # don't use a ssh session
    # there is no "clear" in remote system (or was not at time of writing)
    assert_script_run('cd && reset');
}

sub create_encrypted_part_dasd {
    my $self = shift;
    my $dasd_path = get_var('DASD_PATH', '0.0.0150');
    # activate install-shell to do pre-install dasd-format
    select_console('install-shell');

    # bring dasd online
    # exit status 0 -> everything ok
    # exit status 8 -> unformatted but still usable (e.g. from previous testrun)
    my $r = script_run("dasd_configure $dasd_path 1");
    die "DASD in undefined state" unless (defined($r) && ($r == 0 || $r == 8));
    create_encrypted_part(disk => 'dasda');
    assert_script_run("dasd_configure $dasd_path 0");
}

sub format_dasd {
    my $self = shift;
    my $r;
    my $dasd_path = get_var('DASD_PATH', '0.0.0150');

    # activate install-shell to do pre-install dasd-format
    select_console('install-shell');

    # bring dasd online
    # exit status 0 -> everything ok
    # exit status 8 -> unformatted but still usable (e.g. from previous testrun)
    $r = script_run("dasd_configure $dasd_path 1");
    die "DASD in undefined state" unless (defined($r) && ($r == 0 || $r == 8));

    # make sure that there is a dasda device
    $r = script_run("lsdasd");
    assert_screen("ensure-dasd-exists");
    # always calling debug output, trying to help with poo#12596
    show_debug();
    die "dasd_configure died with exit code $r" unless (defined($r) && $r == 0);

    script_run('lsmod | tee /dev/hvc0');
    # format dasda (this can take up to 20 minutes depending on disk size)
    $r = script_run("echo yes | dasdfmt -b 4096 -p /dev/dasda", 1800);
    show_debug();
    if ($r == 255) {
        record_soft_failure('bsc#1063393');
    }
    else {
        die "dasdfmt died with exit code $r" unless (defined($r) && $r == 0);
    }

    # bring DASD down again to test the activation during the installation
    if (script_run("timeout --preserve-status 20 bash -x /sbin/dasd_configure $dasd_path 0") != 0) {
        record_soft_failure('bsc#1151436');
        script_run('dasd_reload');
        assert_script_run('dmesg');
        assert_script_run("bash -x /sbin/dasd_configure -f $dasd_path 0");
    }
}

sub run {
    my $self = shift;

    select_console 'x3270';
    my $s3270 = console('x3270');

    # Define memory to behave the same way as other archs
    # and to have the same configuration through all s390 guests
    $s3270->sequence_3270('String("DEFINE STORAGE ' . get_var('QEMURAM', 1024) . 'M") ', "ENTER",);
    # arbitrary number of retries for CTC only as it fails often to retrieve
    # media
    my $max_retries = 1;
    if (get_required_var('S390_NETWORK_PARAMS') =~ /ctc/) {
        # CTC still can fail with even 7 retries, see https://progress.opensuse.org/issues/10466
        # so an even higher number is selected which might fix this
        $max_retries = 20;
    }
    for (1 .. $max_retries) {
        eval {
            # connect to zVM, login to the guest
            get_to_yast();
        };
        last unless ($@);
        diag "It looks like CTC network connection is unstable. Retry: $_ of $max_retries" if (get_required_var('S390_NETWORK_PARAMS') =~ /ctc/);
    }

    my $exception = $@;

    # add y2start/log output if exception is happening
    die join("\n", '#', `cat /var/log/YaST2/y2start.log`) if $exception;
    die join("\n", '#' x 67, $exception, '#' x 67) if $exception;

    # activate console so we can call wait_serial later
    # skip activate serial console since 11sp4 has issue bsc#1159521: iucvconn command not exist
    if (!is_sle('=11-sp4')) {
        select_console('iucvconn', await_console => 0);
    }

    # format DASD before installation by default
    format_dasd if (check_var('FORMAT_DASD', 'pre_install'));
    create_encrypted_part_dasd if get_var('ENCRYPT_ACTIVATE_EXISTING');

    select_console("installation");

    # We have textmode installation via ssh and the default vnc installation so far
    if (check_var('VIDEOMODE', 'text') || check_var('VIDEOMODE', 'ssh-x')) {
        # If libyui REST API is used, we set it up in installation/setup_libyui
        unless (get_var('YUI_REST_API')) {
            # Workaround for bsc#1142040
            # enter_cmd("yast.ssh");
            enter_cmd("QT_XCB_GL_INTEGRATION=none yast.ssh") && record_soft_failure('bsc#1142040');
        }
    }
    wait_still_screen;

    $self->result('ok');
}

sub post_fail_hook {
    my $s3270 = console('x3270');
    my $r;

    # Make sure that the screen is updated
    $s3270->sequence_3270("ENTER", "ENTER");
    if (check_screen 'linuxrc', 10) {
        # Start linuxrc shell
        $s3270->sequence_3270(qw(String("x") ENTER String("3") ENTER));
        assert_screen 'linuxrc-shell';

        # collect linuxrc logs
        $s3270->sequence_3270("String(\"cat /var/log/linuxrc.log && echo 'LINUXRC_LOG_SAVED'\")", "ENTER");

        $r = $s3270->expect_3270(
            output_delim => qr/LINUXRC_LOG_SAVED/,
            timeout => 60
        );
        $r ? record_info 'Logs collected', 'Linuxrc logs can be found in autoinst-log.txt' : die "Could not save linuxrc logs";

        assert_screen 'linuxrc-shell';
        # collect wickedd logs
        $s3270->sequence_3270("String(\"cat /var/log/wickedd.log && echo 'WICKED_LOG_SAVED'\")", "ENTER");

        $r = $s3270->expect_3270(
            output_delim => qr/WICKED_LOG_SAVED/,
            timeout => 60
        );
        $r ? record_info 'Logs collected', 'wickedd logs can be found in autoinst-log.txt' : die "Could not save wicked logs";
    }
}

1;
