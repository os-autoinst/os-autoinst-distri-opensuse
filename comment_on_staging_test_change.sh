#! /bin/bash

# Run the script only in case if it is a PR
if [ ! -z "$TRAVIS_PULL_REQUEST" ]; then

    # Workaround due to https://github.com/travis-ci/travis-ci/issues/6069
    git remote set-branches --add origin master
    git fetch

    # Add all changed files under 'test/' folder to the array in the format how they are used in scheduling files (excluding 'tests/' and file extension).
    readarray -t CHANGED_TESTS < <(git diff --name-only origin/master | grep '^tests/*' | cut -f 2- -d '/' | cut -f 1 -d '.')

    # Find files that are matched with the ones in staging scheduling
    declare -a STAGING_TESTS=()
    for TEST in "${CHANGED_TESTS[@]}"
    do
       if MATCHED_TESTS="$(grep --recursive --ignore-case --files-with-matches $TEST schedule/staging/)"
       then
          STAGING_TESTS+=("* \`$TEST\` test is used in \`$MATCHED_TESTS\` schedule")
       fi
    done

    if (( ${#STAGING_TESTS[@]} )); then
      API_PATH="https://api.github.com/repos/${TRAVIS_REPO_SLUG}/issues/${TRAVIS_PULL_REQUEST}/comments"
      # Combine a comment
      COMMENT="Please, execute Verification Run for staging tests as they were changed:\n$(printf "%s\\\n" "${STAGING_FILES[@]}" | sort -u)"
      # Place a comment for the PR
      printf "Test dummy token: ${GH_COMMENT_TOKEN}"
      curl -H "Authorization: token ${GH_COMMENT_TOKEN}" -X POST -d "{\"body\": \"$COMMENT\"}" "$API_PATH"
    fi
fi