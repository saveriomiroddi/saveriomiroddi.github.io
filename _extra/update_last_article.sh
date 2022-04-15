#!/bin/bash

set -o pipefail
set -o errexit
set -o nounset
set -o errtrace
shopt -s inherit_errexit

c_help="Usage: $(basename "$0")

Updates the :last_modified_at, and prepends the file path to the TOC paths.
"

c_posts_path=$(dirname "$0")/../_posts

################################################################################
# MAIN ROUTINES
################################################################################

function decode_cmdline_options {
  if [[ $# -ne 0 ]]; then
    echo "$c_help"
    exit
  fi
}

function find_last_post {
  # shellcheck disable=2012 # don't use find
  echo -n "$c_posts_path/$(ls -1 "$c_posts_path" | tail -n 1)"
}
function update_timestamp {
  local filename=$1

  declare -x timestamp
  timestamp=$(date +"%F %T")

  perl -i -pe 's/^last_modified_at: \K.+/$ENV{timestamp}/' "$filename"
}

function update_toc {
  local filename=$1

  declare -x escaped_title
  escaped_title=$(echo -n "$filename" | perl -ne 'print /\/[\d-]+(.+)\.md$/')

  perl -i -pe 's|^- \[.+\]\(\K(.+)|/$ENV{escaped_title}$1|' "$filename"
}

################################################################################
# MAIN
################################################################################

decode_cmdline_options "$@"
post_filename=$(find_last_post)
update_timestamp "$post_filename"
update_toc "$post_filename"

