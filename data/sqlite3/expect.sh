#!/bin/bash

set timeout 10
spawn sqlite3 --list --header sqlite3/movies.db
expect -nocase "*sqlite*> "
send "SELECT name, year FROM movie LIMIT 2;\n"

expect -nocase "*sqlite*> "
send ".quit\n"

expect eof

