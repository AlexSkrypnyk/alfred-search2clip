#!/usr/bin/env bats
#
# Test for search.sh script.
#
# shellcheck disable=SC2030,SC2031,SC2129

load _helper.bash

# The name of the script to run.
export SCRIPT_FILE="search.sh"

search() {
  cp -Rf "${CURDIR}/tests/fixtures" "${BUILD_DIR}/fixtures"
  export ALFRED_SEARCH2CLIP_PATHS_FILE="${BUILD_DIR}/fixtures/paths.txt"
  run_script "$@"
  assert_success
}

@test "Smoke" {
  assert_contains "scaffold" "${BUILD_DIR}"
}

@test "Unique string" {
  search "abcdef"
  assert_output_contains "abcdef"
  assert_output_contains "file11.txt"
  assert_output_not_contains "nonunique"
  assert_output_not_contains "file12.txt"
  assert_output_not_contains "file21.txt"
  assert_output_not_contains "file22.txt"
  assert_output_not_contains "file23.md"
  assert_output_not_contains "file24.log"

  search "lmnop"
  assert_output_contains "lmnop"
  assert_output_not_contains "file11.txt"
  assert_output_not_contains "file12.txt"
  assert_output_contains "file21.txt"
  assert_output_not_contains "file22.txt"
  assert_output_not_contains "file23.md"
  assert_output_not_contains "file24.log"
}

@test "Non-unique multi-word string" {
  # 'nonunique string with colon : in it and equal'
  search "nonunique equal"
  assert_output_contains "nonunique string with colon : in it and equal"
  assert_output_contains "file11.txt"
  assert_output_contains "file12.txt"
  assert_output_contains "file21.txt"
  assert_output_contains "file22.txt"
  assert_output_contains "file23.md"
  assert_output_not_contains "file24.log"

  # '# nonunique string commented'
  search "# nonunique commented"
  assert_output_contains "# nonunique string commented"
  assert_output_contains "file11.txt"
  assert_output_contains "file12.txt"
  assert_output_contains "file21.txt"
  assert_output_contains "file22.txt"
  assert_output_contains "file23.md"
  assert_output_not_contains "file24.log"
}

@test "Non-unique multi-word string in multiple files" {
  # 'samein2files string something multi'
  search "samein2files"
  assert_output_contains "samein2files string something multi"
  assert_output_not_contains "file11.txt"
  assert_output_contains "file12.txt"
  assert_output_not_contains "file21.txt"
  assert_output_contains "file22.txt"
  assert_output_contains "file23.md"
  assert_output_not_contains "file24.log"

  search "samein2files multi"
  assert_output_contains "samein2files string something multi"
  assert_output_not_contains "file11.txt"
  assert_output_contains "file12.txt"
  assert_output_not_contains "file21.txt"
  assert_output_contains "file22.txt"
  assert_output_contains "file23.md"
  assert_output_not_contains "file24.log"
}

@test "Missing string" {
  search "xyznonexisting"
  assert_output_not_contains "xyznonexisting"
  assert_output_not_contains "file11.txt"
  assert_output_not_contains "file12.txt"
  assert_output_not_contains "file21.txt"
  assert_output_not_contains "file22.txt"
  assert_output_not_contains "file23.md"
  assert_output_not_contains "file24.log"
}

@test "Non-unique multi-word string in multiple files with custom extensions" {
  export ALFRED_SEARCH2CLIP_EXTENSIONS="txt,md,log"

  # 'samein2files string something multi'
  search "samein2files"
  assert_output_contains "samein2files string something multi"
  assert_output_not_contains "file11.txt"
  assert_output_contains "file12.txt"
  assert_output_not_contains "file21.txt"
  assert_output_contains "file22.txt"
  assert_output_contains "file23.md"
  assert_output_contains "file24.log"

  search "samein2files multi"
  assert_output_contains "samein2files string something multi"
  assert_output_not_contains "file11.txt"
  assert_output_contains "file12.txt"
  assert_output_not_contains "file21.txt"
  assert_output_contains "file22.txt"
  assert_output_contains "file23.md"
  assert_output_contains "file24.log"
}

@test "Query with only short words returns no matches" {
  search "a b"
  assert_output_contains '{"items": []}'
}

@test "Query with mixed word lengths uses only long words" {
  search "a nonunique"
  assert_output_contains '"title": "nonunique string"'
  assert_output_not_contains '"title": "a"'
  assert_output_not_contains '"title": "b"'
}

@test "Case-insensitive search" {
  search "NonUnique"
  assert_output_contains '"title": "nonunique string"'
}

@test "Matching multiple words in sequence" {
  search "samein2files mult str"
  assert_output_contains '"title": "samein2files string something multi"'
  assert_output_not_contains '"title": "samein2files mult str12"'
  assert_output_not_contains '"title": "samein2files mult123 str"'
}

@test "Non-matching when extra characters are added to a search term" {
  search "samein2files mult str12"
  assert_output_not_contains '"title": "samein2files string something multi"'
}

@test "Non-matching when characters are inserted within a search term" {
  search "samein2files mult123 str"
  assert_output_not_contains '"title": "samein2files string something multi"'
}
