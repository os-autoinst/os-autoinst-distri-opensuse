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

cd $TRAVIS_BUILD_DIR

pod2html --infile=lib/utils.pm --outfile=docs/utils.html

if [ $(git status | grep "modified docs/utils.html") ] 
then
    git config user.name "Travis CI"
    git config user.email "$COMMIT_AUTHOR_EMAIL"
    git add docs/utils.pm
    git commit -m "Updating the utils documentation"
    git push
fi


