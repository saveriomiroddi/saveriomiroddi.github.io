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
c_front_matter_template='---
layout: post
title: "%s"
tags: []
last_modified_at: 0000-00-00 00:00:00
---

*INTRODUCTION*

Content:

- [First Header](#first-header)

## First Header

'
c_posts_path=$(dirname "$0")/../_posts

v_article_name=

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

function prepare_filename {
  echo -n "$c_posts_path/$(date +"%F")-$(echo -n "$v_article_name" | perl -pe 's/[^\w.]+/-/gi').md"
}

function add_article_file {
  local filename=$1

  echo "File: $filename"
  echo

  local escaped_description
  escaped_description=$(escape_front_matter_value "$v_article_name")

  # shellcheck disable=2059 # (allow variable as template)
  printf -- "$c_front_matter_template" "$escaped_description" | tee "$filename"
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
filename=$(prepare_filename)
add_article_file "$filename"
