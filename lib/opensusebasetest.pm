package opensusebasetest;
use base 'basetest';

use testapi;
use utils;
use strict;

# Base class for all openSUSE tests


# Additional to backend testapi 'clear-console' we do a needle match to ensure
# continuation only after verification
sub clear_and_verify_console {
    my ($self) = @_;

    clear_console;
    assert_screen('cleared-console');

}

sub post_run_hook {
    my ($self) = @_;
    # overloaded in x11 and console
}

sub save_and_upload_log {
    my ($cmd, $file, $args) = @_;
    script_run("$cmd | tee $file", $args->{timeout});
    upload_logs($file) unless $args->{noupload};
    save_screenshot if $args->{screenshot};
}

sub problem_detection {
    my $self = shift;

    type_string "pushd \$(mktemp -d)\n";

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
    save_and_upload_log("journalctl --no-pager -p 'err'", "journalctl-errors.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Tracebacks in journal
    save_and_upload_log('journalctl | grep -i traceback', "journalctl-tracebacks.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Segmentation faults
    save_and_upload_log("coredumpctl list", "segmentation-faults-list.txt", {screenshot => 1, noupload => 1});
    save_and_upload_log("coredumpctl info", "segmentation-faults-info.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Broken links
    save_and_upload_log("find / -type d \\( -path /proc -o -path /run -o -path /.snapshots -o -path /var \\) -prune -o -xtype l -exec ls -l --color=always {} \\; -exec rpmquery -f {} \\;", "broken-symlinks.txt", {screenshot => 1, noupload => 1});
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
    save_and_upload_log("rpmverify -a | grep -v \"[S5T].* c \"", "rpmverify-problems.txt", {timeout => 60, screenshot => 1, noupload => 1});
    clear_console;

    # VMware specific
    if (check_var('VIRSH_VMM_FAMILY', 'vmware')) {
        save_and_upload_log('systemctl status vmtoolsd vgauthd', "vmware-services.txt", {screenshot => 1, noupload => 1});
        clear_console;
    }

    script_run 'tar cvvJf problem_detection_logs.tar.xz *';
    upload_logs('problem_detection_logs.tar.xz');
    type_string "popd\n";
}

sub export_logs {
    select_console 'root-console';
    save_screenshot;

    problem_detection;

    save_and_upload_log('cat /proc/loadavg', '/tmp/loadavg.txt', {screenshot => 1});
    save_and_upload_log('journalctl -b',     '/tmp/journal.log', {screenshot => 1});
    save_and_upload_log('ps axf',            '/tmp/psaxf.log',   {screenshot => 1});

    # Just after the setup: let's see the network configuration
    save_and_upload_log("ip addr show", "/tmp/ip-addr-show.log");

    save_screenshot;

    # check whether xorg logs is exists in user's home, if yes, upload xorg logs from user's
    # home instead of /var/log
    script_run "test -d /home/*/.local/share/xorg ; echo user-xlog-path-\$? > /dev/$serialdev", 0;
    if (wait_serial("user-xlog-path-0", 10)) {
        save_and_upload_log('cat /home/*/.local/share/xorg/X*', '/tmp/Xlogs.log', {screenshot => 1});
    }
    else {
        save_and_upload_log('cat /var/log/X*', '/tmp/Xlogs.log', {screenshot => 1});
    }

    # do not upload empty .xsession-errors
    script_run "xsefiles=(/home/*/.xsession-errors*); for file in \${xsefiles[@]}; do if [ -s \$file ]; then echo xsefile-valid > /dev/$serialdev; fi; done", 0;
    if (wait_serial("xsefile-valid", 10)) {
        save_and_upload_log('cat /home/*/.xsession-errors*', '/tmp/XSE.log', {screenshot => 1});
    }

    save_and_upload_log('systemctl list-unit-files', '/tmp/systemctl_unit-files.log');
    save_and_upload_log('systemctl status',          '/tmp/systemctl_status.log');
    save_and_upload_log('systemctl',                 '/tmp/systemctl.log', {screenshot => 1});
}

# Set a simple reproducible prompt for easier needle matching without hostname
sub set_standard_prompt {
    $testapi::distri->set_standard_prompt;
}

sub select_bootmenu_option {
    my ($self, $tag, $more) = @_;

    assert_screen "inst-bootmenu", 15;

    # after installation-images 14.210 added a submenu
    if ($more && check_screen "inst-submenu-more", 1) {
        if (get_var('OFW')) {
            send_key_until_needlematch 'inst-onmore', 'up';
        }
        else {
            send_key_until_needlematch('inst-onmore', 'down', 10, 5);
        }
        send_key "ret";
    }
    if (get_var('OFW')) {
        send_key_until_needlematch $tag, 'up';
    }
    else {
        send_key_until_needlematch($tag, 'down', 10, 5);
    }
    send_key "ret";
}

1;
# vim: set sw=4 et:
