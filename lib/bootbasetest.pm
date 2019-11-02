package bootbasetest;
use testapi;
use base 'opensusebasetest';
use strict;
use warnings;

sub post_fail_hook {
    # check for text login to check if X has failed
    if (check_screen('generic-login')) {
        record_info 'Seems that the display manager failed';
    }

    # if we found a shell, we do not need the memory dump
    if (!(match_has_tag('emergency-shell') or match_has_tag('emergency-mode'))) {
        if (check_var('BACKEND', 'qemu')) {
            select_console 'root-console';
            diag 'Save memory dump to debug bootup problems, e.g. for bsc#1005313';
            save_memory_dump;
            record_info('Memory dumo', 'Memory dump available for this module');
        } else {
            record_info('No memory dump', 'save_memory_dump not implemented for ' . get_var('BACKEND', 'NO-BACKEND')
                  . ', no way to save memory_dump');
        }
    }

    # crosscheck for text login on tty1
    select_console 'root-console';

    # collect and upload some stuff
    export_logs();
}

1;
