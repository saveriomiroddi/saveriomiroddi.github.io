#!/bin/bash

set -o pipefail
set -o errexit
set -o nounset
set -o errtrace
shopt -s inherit_errexit

# Double quotes are escaped separately!
declare -A c_html_entities=(
  [\']=39
  [:]=58
)
# The bullet list will be interpreted by the Markdown addon as TOC.
# Tags will have a terminating comma, which is ok.
c_front_matter_template='---
layout: post
title: "%s"
tags: [%s]
last_modified_at: 0000-00-00 00:00:00
---

*INTRODUCTION*

Content:

- [First Header](#first-header)

## First Header

'
c_help="Usage: $(basename "$0") <article_name>

Creates the branch, and the article file.
"
c_posts_path=$(dirname "$0")/../_posts
c_tags_path=$(dirname "$0")/../_tags
c_branch_prefix=add_article_

c_editor_program=code

################################################################################
# MAIN ROUTINES
################################################################################

function decode_cmdline_options {
  if [[ $# -ne 1 || $1 == -h || $1 == --help ]]; then
    echo "$c_help"
    exit
  fi

  v_article_name=$1
}

function perform_checks {
  # This messes with Jekyll, which removes trailing minuses during the post URL generation.
  #
  if [[ $v_article_name == *- ]]; then
    >&2 echo "Trailing minus ('-') is not supported in the article name!"
    exit 1
  fi
}

function prepare_article_bare_name {
  echo -n "$(echo -n "$v_article_name" | perl -pe 's/[^\w.]+/-/gi')"
}

function create_git_branch {
  local article_bare_name=${1,,}
  article_bare_name=${article_bare_name//-/_}

  git checkout -b "$c_branch_prefix$article_bare_name"
}

function prepare_article_filename {
  local article_bare_name=$1

  echo -n "$c_posts_path/$(date +"%F")-$article_bare_name.md"
}

# Return the tags, sorted, one per line.
#
function find_tags {
  find "$c_tags_path" -type f -printf '%P\n' | sed 's/\.md$//' | sort
}

function add_article_file {
  local filename=$1 raw_tags=$2 tags

  mapfile -td$'\n' tags <<< "$raw_tags"

  echo "File: $filename"
  echo

  local escaped_description
  escaped_description=$(escape_front_matter_value "$v_article_name")

  # shellcheck disable=2059 # (allow variable as template)
  printf -- "$c_front_matter_template" "$escaped_description" "$(IFS=,; echo "${tags[*]}")" > "$filename"
}

function open_article {
  local filename=$1

  "$c_editor_program" "$filename"
}

################################################################################
# HELPERS
################################################################################

function escape_front_matter_value {
  local result=$1

  for symbol in "${!c_html_entities[@]}"; do
    local code=${c_html_entities[$symbol]}
    export symbol code
    result=$(echo -n "$result" | perl -pe 's/$ENV{symbol}/&#$ENV{code};/g')
  done

  echo -n "$result" | sed 's/"/\\"/g'
}

################################################################################
# MAIN
################################################################################

decode_cmdline_options "$@"
perform_checks
article_bare_name=$(prepare_article_bare_name)
create_git_branch "$article_bare_name"
article_filename=$(prepare_article_filename "$article_bare_name")
v_raw_tags=$(find_tags)
add_article_file "$article_filename" "$v_raw_tags"
open_article "$article_filename"
