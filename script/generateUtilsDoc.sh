#!/bin/bash
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

if [ -z $GITHUB_TOKEN  ]
then
    NEW_DEPLOY_NEEDED=0
    exit 0
fi

cd $TRAVIS_BUILD_DIR

touch docs/utils.html
pod2html --infile=lib/utils.pm --outfile=docs/utils.html

#checkout old docs and compare to new ones, then toggle flag accordingly
git diff gh-pages -- docs/utils.html
ret_val=$?
if [ ${ret_val} -ne 0 ]
then
    NEW_DEPLOY_NEEDED=1
else
    NEW_DEPLOY_NEEDED=0
fi

