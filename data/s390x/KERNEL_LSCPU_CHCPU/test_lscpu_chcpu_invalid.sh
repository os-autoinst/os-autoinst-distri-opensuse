# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

# Load testlib
for f in lib/*.sh; do source $f; done


cleanup(){
 true;
}


invalid_option_lscpu()
{
	start_section 1 "lscpu with invalid option"
	start_section 2 "lscpu with unknown option"
	echo lscpu -z
	lscpu -z
	assert_warn $? 1 "Error message is thrown for invalid option"
	end_section 2
	start_section 2 "lscpu with wrong column name"
	echo lscpu --extended=wefdsa
	lscpu --extended=wefdsa
	assert_warn $? 1 "Error message is thrown for unknown column"
	end_section 2
	end_section 1
}


invalid_option_chcpu()
{
	start_section 1 "chcpu with invalid option"

	start_section 2 "chcpu with -a option"
	echo chcpu -a
	chcpu -a
	assert_warn $? 1 "chcpu displays usage when invalid option is provided"
	end_section 2

	start_section 2 "chcpu to enable non existing cpu"
	echo chcpu -e 30
	chcpu -e 30
	assert_warn $? 64 "chcpu displays error message for non existing cpu"
	end_section 2

	start_section 2 "chcpu to disable non existing cpu"
	echo chcpu -d 40
	chcpu -d 40
	assert_warn $? 64 "chcpu displays error message for non existing cpu"
	end_section 2

	start_section 2 "chcpu to configure non existing cpu"
	echo chcpu -c 30
	chcpu -c 30
	assert_warn $? 64 "chcpu displays error message for non existing cpu"
	end_section 2

        start_section 2 "chcpu to enable out of range cpu"
        echo chcpu -e 3o0
        chcpu -e 300
        assert_warn $? 1 "chcpu displays error message for out of range cpu"
        end_section 2

        start_section 2 "chcpu to disable out of range cpu"
        echo chcpu -d 400
        chcpu -d 400
        assert_warn $? 1 "chcpu displays error message for out of range cpu"
        end_section 2

        start_section 2 "chcpu to configure out of range cpu"
        echo chcpu -c 300
        chcpu -c 300
        assert_warn $? 1 "chcpu displays error message for out of range cpu"

        start_section 2 "chcpu option with char"
        echo chcpu -c 30i
        chcpu -c 30i
        assert_warn $? 1 "chcpu displays error message"
        end_section 2
	end_section 1
}
#############################################################
#main

start_section 0 "START: Test invalid options of lscpu and chcpu"
init_tests
invalid_option_lscpu
invalid_option_chcpu
show_test_results
end_section 0
