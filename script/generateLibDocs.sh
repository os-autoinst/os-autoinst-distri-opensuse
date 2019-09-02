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

    git fetch origin gh-pages:gh-pages

    echo "Documentation of libs" > docs/index.html
    echo "<ul><li>libs/</li><ul>" >> docs/index.html

    for docfile in $(cd lib ; grep -rs ^=head * | grep .pm | cut -d. -f1 | sort -u) ; do
        echo "Generating docs for lib/${docfile}.pm"
        echo "<li><a href="${docfile}.html">${docfile}.pm</a></li>" >> docs/index.html
        mkdir -p docs/$(dirname ${docfile})
        touch docs/${docfile}.html
        pod2html --infile=lib/${docfile}.pm --outfile=docs/${docfile}.html
        # remove line that contains perl version and breaks diff
        sed -i '/^<link rev="made" href="mailto:/d' docs/${docfile}.html
        stylepath=$(dirname ${docfile} | sed 's|[^/.][^/.]*|..|g')
        sed -i "s|^</head>|<link rel='stylesheet' href='${stylepath}/style.css' />\n</head>|" docs/${docfile}.html
        sed -i "s|></title>|>lib/${docfile}.pm</title>|" docs/${docfile}.html
        sed -i "s|^</ul>|</ul><h1>lib/${docfile}.pm</h1>|" docs/${docfile}.html

        #checkout old docs and compare to new ones, then toggle flag accordingly
        git checkout gh-pages ${docfile}.html 2>/dev/null || touch ${docfile}.html
        diff -u ${docfile}.html docs/${docfile}.html
        diff_ret_val=$?
        if [ "${ret_val}" = "0" ] ; then
            ret_val="$diff_ret_val"
        fi
        git reset HEAD ${docfile}.html
        rm ${docfile}.html
    done

    echo "</ul></ul>" >> docs/index.html

    if [ "${ret_val}" != "0" ] ; then
        NEW_DEPLOY_NEEDED=1
    else
        NEW_DEPLOY_NEEDED=0
    fi
fi
