#!/bin/bash

set -o pipefail
set -o errexit
set -o nounset
set -o errtrace
shopt -s inherit_errexit

c_help="Usage: $(basename "$0") [<filename>]

Updates the :last_modified_at, and prepends the file path to the TOC paths.

If <filename> is not specified, the last article is updated.
"

c_posts_path=$(dirname "$0")/../_posts

v_post_filename=

################################################################################
# MAIN ROUTINES
################################################################################

function decode_cmdline_options {
  if [[ $# -gt 1 || ${1:-} == -h || ${1:-} == --help ]]; then
    echo "$c_help"
    exit
  fi

  v_post_filename=${1:-}
}

function find_last_post {
  # shellcheck disable=2012 # don't use find
  echo -n "$c_posts_path/$(ls -1 "$c_posts_path" | tail -n 1)"
}
function update_timestamp {
  declare -x timestamp
  timestamp=$(date +"%F %T")

  perl -i -pe 's/^last_modified_at: \K.+/$ENV{timestamp}/' "$v_post_filename"
}

function update_toc {
  declare -x escaped_title
  escaped_title=$(echo -n "$v_post_filename" | perl -ne 'print /\/[\d-]+(.+)\.md$/')

  perl -i -pe 's|^- \[.+\]\(\K(.+)|/$ENV{escaped_title}$1|' "$v_post_filename"
}

################################################################################
# MAIN
################################################################################

decode_cmdline_options "$@"
v_post_filename=${v_post_filename:-$(find_last_post)}
update_timestamp
update_toc

