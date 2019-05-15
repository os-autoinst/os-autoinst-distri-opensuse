# SUSE"s openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Regression test for rrdtool
# - created, update rrd file
# - fetch data from file
# - generate images with different options
# - compare images with needles
# Expected result:
# 4 graphics will be displayed without error.
#
# Maintainer: Marcelo Martins <mmartins@suse.cz>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub verify_rrd_image {
    my $rrdtool_image = shift;
    send_key("alt-f2");
    type_string("eog /tmp/rrdtool/${rrdtool_image}.png\n");
    assert_screen "rrdtool_image_${rrdtool_image}";
    send_key 'alt-f4';
    assert_screen "rrdtool_xterm";
}

sub rrdtool_update {
    my $data = shift;
    assert_script_run "rrdtool update test.rrd ${data}";
}

sub run {
    select_console 'x11';
    x11_start_program('xterm');
    become_root;
    pkcon_quit;
    # create a tmp dir/files to work
    assert_script_run "mkdir /tmp/rrdtool; cd /tmp/rrdtool";
    # install requirements
    zypper_call "in rrdtool eog";
    # create a rrd file
    assert_script_run "rrdtool create test.rrd --start 920804400  DS:speed:COUNTER:600:U:U RRA:AVERAGE:0.5:1:24 RRA:AVERAGE:0.5:6:10";
    # update the rrd file
    rrdtool_update '920804700:12345 920805000:12357 920805300:12363';
    rrdtool_update '920805600:12363 920805900:12363 920806200:12373';
    rrdtool_update '920806500:12383 920806800:12393 920807100:12399';
    rrdtool_update '920807400:12405 920807700:12411 920808000:12415';
    rrdtool_update '920808300:12420 920808600:12422 920808900:12423';

    # fetch the rrd file
    assert_script_run "rrdtool fetch test.rrd AVERAGE --start 920804400 --end 920809200";

    # make the graph 1.
    assert_script_run "rrdtool graph speed-1.png --start 920804400 --end 920808000 DEF:myspeed=test.rrd:speed:AVERAGE LINE2:myspeed#FF0000";
    #open image and verify if correct.
    verify_rrd_image 'speed-1';

    # make the graph 2.
    assert_script_run "rrdtool graph speed-2.png --start 920804400 --end 920808000 --vertical-label m/s DEF:myspeed=test.rrd:speed:AVERAGE CDEF:realspeed=myspeed,1000,* LINE2:realspeed#FF0000";
    #open image and verify if correct.
    verify_rrd_image 'speed-2';

    # make the graph 3. Used type_string_slow to run with sle15+, other way, command broken.
    type_string_slow 'rrdtool graph speed-3.png --start 920804400 --end 920808000 --vertical-label km/h DEF:myspeed=test.rrd:speed:AVERAGE "CDEF:kmh=myspeed,3600,*" CDEF:fast=kmh,100,GT,kmh,0,IF CDEF:good=kmh,100,GT,0,kmh,IF HRULE:100#0000FF:"Maximum allowed" AREA:good#00FF00:"Good speed" AREA:fast#FF0000:"Too fast"';
    send_key 'ret';
    #open image and verify if correct.
    verify_rrd_image 'speed-3';

    # make the graph 4.
    assert_script_run 'rrdtool graph speed-4.png --start 920804400 --end 920808000 --vertical-label km/h DEF:myspeed=test.rrd:speed:AVERAGE "CDEF:kmh=myspeed,3600,*" CDEF:fast=kmh,100,GT,100,0,IF CDEF:over=kmh,100,GT,kmh,100,-,0,IF CDEF:good=kmh,100,GT,0,kmh,IF HRULE:100#0000FF:"Maximum allowed" AREA:good#00FF00:"Good speed" AREA:fast#550000:"Too fast" STACK:over#FF0000:"Over speed"';
    #open image and verify if correct.
    verify_rrd_image 'speed-4';

    #clean files.
    assert_script_run "cd ; rm -rf /tmp/rrdtool";
    send_key 'alt-f4';
}

1;
