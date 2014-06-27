use base "basetest";
use strict;
use bmwqemu;

# have various useful general info included in videos
sub run() {
    my $self = shift;
    script_run('uname -a');
    script_run('free');
    script_run('/usr/sbin/btrfs filesystem df /');
    save_screenshot;
    send_key "ctrl-l";                      # clear the screen
    script_run('df -h');
    save_screenshot;
    send_key "ctrl-l";                      # clear the screen
    script_run('ip -o a s');
    save_screenshot;
    send_key "ctrl-l";                      # clear the screen
    script_run('ip r s');
    script_run('ip -6 r s');
    save_screenshot;
    send_key "ctrl-l";                      # clear the screen
    script_run('cat /etc/resolv.conf');
    script_run('ls -al /etc/sysconfig/network');
    save_screenshot;
    send_key "ctrl-l";                      # clear the screen
    script_run('rpm -qa kernel-*');
    script_run('grep DISPLAYMANAGER /etc/sysconfig/displaymanager');
    script_run('grep DEFAULT /etc/sysconfig/windowmanager');
    script_run("ls -l /etc/ntp*");
    script_run("du /var/log/messages");
    assert_screen 'test-textinfo-1', 3;
    local $vars{SCREENSHOTINTERVAL} = 3;    # uninteresting stuff for automatic processing:
    script_run("ps ax > /dev/$serialdev");
    script_run("systemctl --no-pager --full > /dev/$serialdev");
    script_run("rpm -qa > /dev/$serialdev && echo 'rpm_qa_outputted' > /dev/$serialdev");
    wait_serial 'rpm_qa_outputted', 30  || die "rpm_qa_outputted cannot found or it took too long time to finish";
    save_screenshot;
    send_key "ctrl-l";                      # clear the screen
    script_sudo("tar cjf /tmp/logs.tar.bz2 /var/log");
    upload_logs("/tmp/logs.tar.bz2");
    script_run("echo 'textinfo_ok' >  /dev/$serialdev");
    wait_serial 'textinfo_ok', 5  || die "textinfo test failed";
    save_screenshot;

}

1;
# vim: set sw=4 et:
