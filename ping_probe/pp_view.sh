#!/bin/bash

source ./pp_config.cfg


# COLORS
DEFAULT='\e[39m'
RED='\e[91m'
GREEN='\e[92m'
YELLOW='\e[93m'
GREY='\e[90m'

LATENCY_LIMIT_MILISECONDS=5.0

# FCE: parse_data
# ARGS (3): timestamp, hostname and latency
# DESC: Prints data in redable format (can include colors).
function print_data() {
	printf "%-10s:   %-15s %10s ms\n" "$1" "$2" "$3"
}

function data_colorizer() {
	# TODO: Fix localhost format problem - indentation of next value
	timestamp="${YELLOW}${1}${DEFAULT}"
	hostname="$(if [[ $2 == localhost ]];then echo ${GREY}${2}${DEFAULT};else echo ${DEFAULT}${2}${DEFAULT};fi)"
	if [[ $(bc <<< "$3 < $LATENCY_LIMIT_MILISECONDS") -eq 1 ]];then
		latency="${RED}${3}${DEFAULT} ms"
	else
		latency="${DEFAULT}${3}${DEFAULT} ms"
	fi
	printf "%-10s:  %-30s %20s\n" "$timestamp" "$hostname" "$latency" 
}

sqlite3 $DB_FILE 'SELECT timestamp, hostname, latency FROM latency;' | while read line;do
	echo -e "$(data_colorizer $(echo $line | tr '|' ' '))"
done
