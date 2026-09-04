# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test chocolate-doom initial startup
# Maintainer: okurz@suse.de

from testapi import *

def run(self):
    select_console('x11')
    perl.require('x11test')
    ensure_installed('chocolate-doom')
    x11_start_program('chocolate-doom')
    send_key('alt-f4')
