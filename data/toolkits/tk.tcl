#!/usr/bin/wish

# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

tk scaling 1.0
image create photo logo -file $tk_library/demos/images/tcllogo.gif
label .hello -compound bottom -text "Hello World: Tcl/Tk" -image logo
pack .hello
