# Copyright (C) 2014 SUSE Linux Products GmbH
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
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use base 'basetest';
use testapi;

sub save_logs_and_continue
{
    my $name = shift;
    # seve logs and continue
    send_key "ctrl-alt-f2";
    send_key "alt-f2";
    sleep 5;
    wait_idle(5);
    assert_screen "inst-console";
    type_string "save_y2logs /tmp/y2logs-$name.tar.bz2\n";
    upload_logs "/tmp/y2logs-$name.tar.bz2";
    save_screenshot;
    send_key "ctrl-l";
    send_key "alt-f7";
    wait_idle(5);
}


sub run {
    my $self = shift;
    $self->result('ok');
    # wait for bootloader to appear
    my $ret;

    my @needles = ("inst-bootmenu", "autoyast-error", "reboot-after-installation");

    push @needles, "autoyast-confirm" if get_var("AUTOYAST_CONFIRM");
    push @needles, "autoyast-postpartscript" if get_var("USRSCR_DIALOG");
    my $postpartscript = 0;
    my $confirmed = 0;

    my $maxtime = 2000;
    my $checktime = 30;
    my $looptime = 0;
    my $i = 1;
    my $timeout = 0;

    while (! $timeout) {
        mouse_hide(1);
        $ret = check_screen( [@needles], $checktime );

        #repeat until timeout or login screen
        if ( defined $ret ) {
           last if $ret->{needle}->has_tag("inst-bootmenu") || $ret->{needle}->has_tag("reboot-after-installation");
 
           if ( $ret->{needle}->has_tag('autoyast-error') ) {
              send_key "alt-s"; #stop
              save_logs_and_continue("stage1_error$i");
              $i++;
              send_key "tab"; #continue
              send_key "ret";
              wait_idle(5);
              #mark as failed
              $self->result('fail');
           }
           elsif ( $ret->{needle}->has_tag('autoyast-confirm') ) {
              # select network (second entry)
              send_key "ret";

              assert_screen( "startinstall", 20 );

              send_key "tab";
              send_key "ret";
              wait_idle(5);
              @needles = grep { $_ ne 'autoyast-confirm' } @needles;
              $confirmed = 1;
           }
           elsif ( $ret->{needle}->has_tag('autoyast-postpartscript') ) {
              @needles = grep { $_ ne 'autoyast-postpartscript' } @needles;
              $postpartscript = 1;
           }
        }

        $looptime = $looptime + $checktime;
        $timeout = 1 if $looptime > $maxtime;

    }


    if ($timeout) { #timeout - save log
        save_logs_and_continue("stage1_timeout");
        $self->result('fail');
        return;
    }

    if (get_var("USRSCR_DIALOG")) {
        $self->result('fail') if !$postpartscript;
    }

    if (get_var("AUTOYAST_CONFIRM")) {
        $self->result('fail') if !$confirmed;
    }



    $maxtime = 1000;
    $checktime = 30;
    $looptime = 0;
    $timeout = 0;
    while (! $timeout) {

        mouse_hide(1);
        $ret = check_screen( ["reboot-after-installation", "autoyast-error" ], $checktime );

        
        #repeat until timeout or login screen
        if ( defined $ret ) {
           if ( $ret->{needle}->has_tag('autoyast-error') ) {
              send_key "alt-s"; #stop
              save_logs_and_continue("stage2_error$i");
              $i++;
              send_key "tab"; #continue
              send_key "ret";
              wait_idle(5);
              #mark as failed
              $self->result('fail');
           }
           else { #all ok
              last;
           }
        }
        $looptime = $looptime + $checktime;
        $timeout = 1 if $looptime > $maxtime;

    }
    
    if ($timeout) { #timeout - save log
        save_logs_and_continue("stage2_timeout");
        $self->result('fail');
        return;
    }

    #go to text console if graphical login detected
    send_key "ctrl-alt-f1" if $ret->{needle}->has_tag('displaymanager');




}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1 };
}

1;

# vim: set sw=4 et:
