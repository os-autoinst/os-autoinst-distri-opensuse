# Copyright (C) 2015 SUSE Linux GmbH
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

# Summary: Autoyast installation
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use strict;
use base 'basetest';
use testapi;
use utils;

my $confirmed_licenses = 0;

sub accept_license {
    send_key $cmd{accept};
    $confirmed_licenses++;
    # Prevent from matching previous license
    wait_screen_change {
        send_key $cmd{next};
    };
}

sub save_logs_and_continue {
    my $name = shift;
    # save logs and continue
    send_key "ctrl-alt-f2";
    send_key "alt-f2";
    sleep 5;
    wait_idle(5);
    assert_screen ["inst-console"];

    # the network may be down with keep_install_network=false
    # use static ip in that case
    type_string "
      save_y2logs /tmp/y2logs-$name.tar.bz2
      if ! ping -c 1 10.0.2.2 ; then
        ip addr add 10.0.2.200/24 dev eth0
        ip link set eth0 up
        route add default gw 10.0.2.2
      fi
    ";
    upload_logs "/tmp/y2logs-$name.tar.bz2";
    save_screenshot;
    clear_console;
    send_key "alt-f7";
    wait_idle(5);
}

sub save_logs_in_linuxrc {
    my $name = shift;
    # tty9 is available in linuxrc
    send_key "ctrl-alt-f9";
    send_key "alt-f9";
    sleep 5;
    assert_screen ["inst-console"];

    # save_y2logs is not present
    assert_script_run "tar czf /tmp/logs-$name.tar.bz2 /var/log";
    upload_logs "/tmp/logs-$name.tar.bz2";
}

sub run {
    my $self = shift;
    $self->result('ok');
    # wait for bootloader to appear
    my $ret;

    my @needles = ("bios-boot", "autoyast-error", "reboot-after-installation", "linuxrc-install-fail");

    push @needles, "autoyast-confirm"        if get_var("AUTOYAST_CONFIRM");
    push @needles, "autoyast-postpartscript" if get_var("USRSCR_DIALOG");
    if (get_var("AUTOYAST_LICENSE")) {
        if (get_var("BETA")) {
            push @needles, "inst-betawarning";
        }
        else {
            push @needles, "autoyast-license";
        }
    }

    my $postpartscript = 0;
    my $confirmed      = 0;

    my $maxtime     = 2000;
    my $confirmtime = 200;

    my $checktime  = 30;
    my $looptime   = 0;
    my $i          = 1;
    my $timeout    = 0;
    my $num_errors = 0;

    while (!$timeout) {
        mouse_hide(1);
        $ret = check_screen([@needles], $checktime);

        #repeat until timeout or login screen
        if (defined $ret) {
            last if match_has_tag("bios-boot") || match_has_tag("reboot-after-installation");

            if (match_has_tag('autoyast-error')) {
                record_soft_failure 'AUTOYAST_EXPECT_ERRORS ' . get_var('AUTOYAST_EXPECT_ERRORS_REASON');
                send_key "alt-s";    #stop
                save_logs_and_continue("stage1_error$i");
                $i++;
                send_key "tab";      #continue
                send_key "ret";
                wait_idle(5);
                $num_errors++;
            }
            if (match_has_tag('linuxrc-install-fail')) {
                save_logs_in_linuxrc("stage1_error$i");
                die "installation ends in linuxrc";
            }
            elsif (match_has_tag('autoyast-confirm')) {
                # select network (second entry)
                send_key "ret";

                assert_screen("startinstall", 20);

                send_key "tab";
                send_key "ret";
                wait_idle(5);
                @needles = grep { $_ ne 'autoyast-confirm' } @needles;
                $confirmed = 1;
            }
            elsif (match_has_tag('autoyast-license')) {
                accept_license;
            }
            elsif (match_has_tag('inst-betawarning')) {
                send_key $cmd{ok};
                assert_screen 'autoyast-license';
                accept_license;
            }
            elsif (match_has_tag('autoyast-postpartscript')) {
                @needles = grep { $_ ne 'autoyast-postpartscript' } @needles;
                $postpartscript = 1;
            }
        }

        $looptime = $looptime + $checktime;
        $timeout  = 1 if $looptime > $maxtime;
        $timeout  = 1 if get_var("AUTOYAST_CONFIRM") && $looptime > $confirmtime && !$confirmed;
    }


    if ($timeout) {    #timeout - save log
        save_logs_and_continue("stage1_timeout");
        die "timeout hit";
    }

    if (get_var("USRSCR_DIALOG")) {
        die "usrscr dialog" if !$postpartscript;
    }

    if (get_var("AUTOYAST_CONFIRM")) {
        die "autoyast_confirm" if !$confirmed;
    }

    if (get_var("AUTOYAST_LICENSE")) {
        if ($confirmed_licenses == 0 || $confirmed_licenses != get_var("AUTOYAST_LICENSE", 0)) {
            die "autoyast_license";
        }
    }

    # CaaSP does not have second stage
    return if is_casp;

    $maxtime   = 1000;
    $checktime = 30;
    $looptime  = 0;
    $timeout   = 0;
    while (!$timeout) {

        mouse_hide(1);
        $ret = check_screen(["reboot-after-installation", "autoyast-error"], $checktime);

        #repeat until timeout or login screen
        if (defined $ret) {
            if (match_has_tag('autoyast-error')) {
                record_soft_failure 'AUTOYAST_EXPECT_ERRORS ' . get_var('AUTOYAST_EXPECT_ERRORS_REASON');
                send_key "alt-s";    #stop
                save_logs_and_continue("stage2_error$i");
                $i++;
                send_key "tab";      #continue
                send_key "ret";
                wait_idle(5);
                $num_errors++;
            }
            else {                   #all ok
                last;
            }
        }
        $looptime = $looptime + $checktime;
        $timeout = 1 if $looptime > $maxtime;
    }

    if ($timeout) {                  #timeout - save log
        save_logs_and_continue("stage2_timeout");
        die "stage2_timeout";
        return;
    }

    my $expect_errors = get_var("AUTOYAST_EXPECT_ERRORS") // 0;
    if ($num_errors != $expect_errors) {
        die "exceeded expected autoyast errors";
    }

    #go to text console if graphical login detected
    send_key "ctrl-alt-f1" if match_has_tag('displaymanager');
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
