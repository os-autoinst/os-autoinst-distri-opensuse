#!/bin/bash
#
# Copyright (C) 2019 SUSE LLC
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

NEW_DEPLOY_NEEDED=0

if [ -z $GITHUB_TOKEN  ] ; then
    NEW_DEPLOY_NEEDED=0
else
    cd $TRAVIS_BUILD_DIR

    touch docs/utils.html
    pod2html --infile=lib/utils.pm --outfile=docs/utils.html
    # remove line that contains perl version and breaks diff
    sed -i '/^<link rev="made" href="mailto:/d' docs/utils.html

    #checkout old docs and compare to new ones, then toggle flag accordingly
    git fetch origin gh-pages:gh-pages
    git checkout gh-pages utils.html
    diff -u utils.html docs/utils.html
    ret_val=$?
    git reset HEAD utils.html
    rm utils.html
    if [ ${ret_val} -ne 0 ] ; then
        NEW_DEPLOY_NEEDED=1
    else
        NEW_DEPLOY_NEEDED=0
    fi
fi
