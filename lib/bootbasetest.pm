package bootbasetest;
use testapi;
use base 'opensusebasetest';
use strict;
use warnings;

sub post_fail_hook {
    my ($self) = @_;
    # check for text login to check if X has failed
    if (check_screen('generic-login')) {
        record_info 'Seems that the display manager failed';
    }

    # crosscheck for text login on tty1
    select_console 'root-console';

    # collect and upload some stuff
    $self->SUPER::export_logs();

    # Dump memory on qemu backend
    if (check_var('BACKEND', 'qemu') && get_var('DEBUG_DUMP_MEMORY')) {
        diag 'Save memory dump to debug bootup problems, e.g. for bsc#1005313';
        save_memory_dump;
    }
}

1;
