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

v_run_checks=1 # boolean; false=empty, true=anything else
v_post_filename=

################################################################################
# MAIN ROUTINES
################################################################################

function decode_cmdline_options {
  local params
  params=$(getopt --options hc --long help,nocheck --name "$(basename "$0")" -- "$@")

  eval set -- "$params"

  while true; do
    case $1 in
      -h|--help)
        echo "$c_help"
        exit 0 ;;
      -c|--nocheck)
        v_run_checks=
        shift ;;
      --)
        shift
        break ;;
    esac
  done


  if [[ $# -gt 1 ]]; then
    echo "$c_help"
    exit
  fi

  v_post_filename=${1:-}
}

function find_last_post {
  # shellcheck disable=2012 # don't use find
  ls -1 "$c_posts_path"/*.md | tail -n 1
}

# Make sure that we don't find a TOC with processed links, because we don't know if it's been updated
# or not.
#
function check_table_has_no_processed_links {
  if grep -qP '^- +\[.+\]\(/' "$v_post_filename"; then
    >&2 echo "The post includes processed links! Regenerate the TOC, or update with --nocheck."
    exit 1
  fi
}

function timestamp_present {
  grep -qP '^last_modified_at:' "$v_post_filename"
}

function update_timestamp {
  declare -x timestamp
  timestamp=$(date +"%F %T")

  perl -i -pe 's/^last_modified_at: \K.+/$ENV{timestamp}/' "$v_post_filename"
}

function add_timestamp {
  declare -x timestamp
  timestamp=$(date +"%F %T")

  # Assumes that the title doesn't match `---`
  #
  sed -zi "s/---/last_modified_at: $timestamp\n---/2" "$v_post_filename"
}

function update_toc {
  declare -x escaped_title
  escaped_title=$(echo -n "$v_post_filename" | perl -ne 'print /\/[\d-]+(.+)\.md$/')

  # Useful when testing, as one may create an unexpected title.
  #
  if [[ -z $escaped_title ]]; then
    >&2 echo "Unexpected format for post filename!"
    exit 1
  fi

  # See check_table_has_no_processed_links().
  #
  perl -i -pe 's|^ *- \[.+\]\(\K(.+)|/$ENV{escaped_title}$1|' "$v_post_filename"
}

################################################################################
# MAIN
################################################################################

decode_cmdline_options "$@"
v_post_filename=${v_post_filename:-$(find_last_post)}
if [[ -n $v_run_checks ]]; then
  check_table_has_no_processed_links
fi
if timestamp_present; then
  update_timestamp
else
  add_timestamp
fi
update_toc
