#!/bin/bash
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

git fetch origin gh-pages:gh-pages

echo "Documentation of libs" > docs/index.html
echo "<ul><li>libs/</li><ul>" >> docs/index.html

ret_val=0

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
    sed -i "s|<ul id=\"index\">|<ul id=\"index\"><li><a href=\"${stylepath}/index.html\"><i>\&lt;= Back to file list</i></a></li>|" docs/${docfile}.html
    # only replace first occurrence
    awk "NR==1,/^<\/ul>/{sub(/^<\/ul>/, \"</ul><h1>lib/${docfile}.pm</h1>\")} 1" docs/${docfile}.html > docs/${docfile}.html.tmp
    mv docs/${docfile}.html.tmp docs/${docfile}.html

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
