# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: tomboy: Test 'undo'/'Redo' feature
# Maintainer: Sero Sun <yosun@suse.com>
# Tags: tc#1248884

use base 'x11test';
use strict;
use warnings;
use testapi;


sub run {
    # open tomboy
    x11_start_program('tomboy note', valid => 0);

    # create a note type something and undo it
    wait_screen_change { send_key 'ctrl-n' };
    wait_screen_change { type_string 'hehe' };
    wait_screen_change { send_key 'ctrl-z' };
    assert_screen 'test-tomboy_TestUndoRedoFeature-1', 3;
    wait_screen_change { type_string 'hehe' };
    wait_screen_change { send_key 'alt-f4' };

    # reopen it and undo again, check the last change still can be undo
    wait_screen_change { send_key 'alt-f9' };
    wait_screen_change { send_key 'tab' };
    wait_screen_change { send_key 'up' };
    wait_screen_change { send_key 'ret' };
    wait_screen_change { send_key 'ctrl-z' };
    assert_screen 'test-tomboy_TestUndoRedoFeature-2', 3;
    wait_screen_change { send_key 'alt-f4' };

    # Edit not and redo
    wait_screen_change { send_key 'alt-f9' };
    wait_screen_change { send_key 'tab' };
    wait_screen_change { send_key 'up' };
    wait_screen_change { send_key 'ret' };
    wait_screen_change { type_string 'hehe' };
    wait_screen_change { send_key 'ctrl-z' };
    wait_screen_change { send_key 'shift-ctrl-z' };
    assert_screen 'test-tomboy_TestUndoRedoFeature-3', 3;
    wait_screen_change { send_key 'ctrl-z' };
    wait_screen_change { send_key 'alt-f4' };

    # Reopen it and redo
    wait_screen_change { send_key 'alt-f9' };
    wait_screen_change { send_key 'tab' };
    wait_screen_change { send_key 'up' };
    wait_screen_change { send_key 'ret' };
    wait_screen_change { send_key 'shift-ctrl-z' };
    assert_screen 'test-tomboy_TestUndoRedoFeature-4', 3;
    wait_screen_change { send_key 'alt-f4' };

    # Delete the note
    wait_screen_change { send_key 'alt-f9' };
    wait_screen_change { send_key 'tab' };
    wait_screen_change { send_key 'up' };
    wait_screen_change { send_key 'delete' };
    wait_screen_change { send_key 'alt-d' };
    wait_screen_change { send_key 'alt-f4' };

    # Kill tomboy note
    x11_start_program('killall tomboy', valid => 0);
}

1;
