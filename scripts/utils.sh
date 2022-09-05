#!/bin/bash

# utilities
function parse_yaml_file {
   local prefix=$2
   local separator=$3
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   if [[ -z "$separator" ]]; then separator="_"; fi
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("'$separator'")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

function print_error() {
    printf "\033[0;31mError\033[0m ${1}\n"
}

function print_log() {
    printf "$(date +'[%Y-%m-%d %M:%M:%S]') $1\n"
}

function print_red() {
    printf "\033[0;31m${1}\033[0m\n"
}

function print_yellow() {
    printf "\033[0;93m${1}\033[0m\n"
}

function print_green() {
    printf "\033[1;32m${1}\033[0m\n"
}