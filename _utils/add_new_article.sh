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
c_posts_path=$(dirname "$0")/../_posts
c_tags_path=$(dirname "$0")/../_tags

v_tags=

################################################################################
# MAIN ROUTINES
################################################################################

function decode_cmdline_options {
  if [[ $# -ne 1 || $1 == -h || $1 == --help ]]; then
    echo "\
Usage: $(basename "$0") <article_name>
"
    exit
  fi

  v_article_name=$1
}

function prepare_article_bare_name {
  echo -n "$(echo -n "$v_article_name" | perl -pe 's/[^\w.]+/-/gi')"
}

function prepare_article_filename {
  local article_bare_name=$1

  echo -n "$c_posts_path/$(date +"%F")-$article_bare_name.md"
}

function find_and_set_tags {
  mapfile -td$'\n' v_tags < <(find "$c_tags_path" -type f -printf '%P\n' | sed 's/\.md$//' | sort)
}

function add_article_file {
  local filename=$1

  echo "File: $filename"
  echo

  local escaped_description
  escaped_description=$(escape_front_matter_value "$v_article_name")

  # shellcheck disable=2059 # (allow variable as template)
  printf -- "$c_front_matter_template" "$escaped_description" "$(IFS=,; echo "${v_tags[*]}")" | tee "$filename"
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

  echo -n "$result" | sed 's/"/\\"/'
}

################################################################################
# MAIN
################################################################################

decode_cmdline_options "$@"
article_bare_name=$(prepare_article_bare_name)
article_filename=$(prepare_article_filename "$article_bare_name")
find_and_set_tags # sets v_tags
add_article_file "$article_filename"
