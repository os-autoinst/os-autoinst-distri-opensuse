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

GITHUB_REPO=":DrMullings/os-autoinst-distri-opensuse.git"

cd $TRAVIS_BUILD_DIR

pod2html --infile=lib/utils.pm --outfile=docs/utils.html
git status | grep 'modified:   docs/utils.html'
retVal=$?
echo $retVal

#if [ ${CONTINOUS_INTEGRATION} ]
#then
    #if [ "${TRAVIS_BRANCH}" != "master" ]
    #then
    #    echo "Branch is ${TRAVIS_BRANCH}, not generating any documentation"
    #    exit 0
    #fi

    #if [ "${TRAVIS_PULL_REQUEST}" != false ]
    #then
    #    echo "Build is pull request, not generating any documentation"
    #    exit 0
    #fi

    #if [ $retVal -eq 0 ]
    #then
    #    echo "Utils changed, generating new documentation"
        #git config user.name "Travis CI"
        #git config user.email "$COMMIT_AUTHOR_EMAIL"
        #git config github.user "DrMullings"
        #git config github.token "$GITHUB_TOKEN"
        #git checkout master
        #git add docs/utils.html
        #git commit -m "Updating the utils documentation"
        #git push --force --quiet "https://${GITHUB_TOKEN}@github.com${GITHUB_REPO} master:master"
    #fi
#fi
