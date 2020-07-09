#!/bin/bash

source ./pp_config.cfg

TIMESTAMP_OPT_VALUE='all'

# Default uncolored
DEFAULT='\e[39m'
RED='\e[39m'
GREEN='\e[39m'
YELLOW='\e[39m'
GREY='\e[39m'


#./pp_view.sh -t [today, yesterday, +timestamp(higher then), -timestamp(lower then), timestamp1-timestamp2]
#./pp_view.sh -
#./pp_view.sh

function parse_arguments () {
	while true;do
		[[ -z $1 ]] && break
		case "$1" in
			'-t')	
				echo Managing-timestamp
				# code of timestamp option
				shift
				if ! [[ $1 =~ ^$|-c ]];then
					TIMESTAMP_OPT_VALUE="$1"
					echo "DEBUG: -t value: $TIMESTAMP_OPT_VALUE"
					shift
				else
					echo "ERROR: Missing -t TIMESTAMP value"
					exit 1
				fi

				# TODO: Rework echo into something more radable
				# 	Handle number order in range
				if ! $(echo $TIMESTAMP_OPT_VALUE | grep -Ew 'all|today|yesterday|\+[0-9]+|-[0-9]+|[0-9]+-[0-9]+' > /dev/null);then
					echo "ERROR: Invalid timestamp value: $TIMESTAMP_OPT_VALUE"
					echo Valid input values:
					echo -e "\t'all'\t All known database data"
					echo -e "\t'today'\t from today 0:00 AM - now"
					echo -e "\t'yesterday'\t yesterday 0:00 AM - 23:59:59 PM"
					echo -e "\t'+TIMESTAMP'\t higher then timestamp"
					echo -e "\t'-TIMESTAMP'\t lower then timestamp"
					echo -e "\t'TIMESTAMP1-TIMESTAMP2'\t timestamp range"
					exit 1
				fi
				;;
			'-c')
				echo "DEBUG: -c option exists"
				
				# COLORS
				DEFAULT='\e[39m'
				RED='\e[91m'
				GREEN='\e[92m'
				YELLOW='\e[93m'
				GREY='\e[90m'
				
				shift
				;;
			*)
				echo "ERROR: Invalid input: $1"
                        	exit 1
				;;
		esac	
	done
	
}

parse_arguments $@

LATENCY_LIMIT_MILISECONDS=7.0

# FCE: parse_data
# ARGS (3): timestamp, hostname and latency
# DESC: Prints data in redable format (can include colors).
function print_data() {
	printf "%-10s:   %-15s %10s ms\n" "$1" "$2" "$3"
}

function data_colorizer() {
	# TODO: Fix localhost format problem - indentation of next value
	timestamp="${YELLOW}${1}${DEFAULT}"
	
	if [[ $2 == localhost ]];then
		hostname="${GREY}${2}${DEFAULT}"
	else
		hostname="${DEFAULT}${2}${DEFAULT}"
	fi

	if [[ $(bc <<< "$3 > $LATENCY_LIMIT_MILISECONDS") -eq 1 ]];then
		latency="${YELLOW}${3}${DEFAULT} ms"
	elif [[ $(bc <<< "$3 == -99") -eq 1 ]];then
		latency="${GREY}Timeout${DEFAULT}"
	elif [[ $(bc <<< "$3 == -1") -eq 1 ]];then
		latency="${RED}Error${DEFAULT}" 
	else
		latency="${DEFAULT}${3}${DEFAULT} ms"
	fi
	
	printf "%-10s:  %-30s %20s\n" "$timestamp" "$hostname" "$latency" 
}


# TODO: Make variants for different timestamp values
#	Use bash parameter expansion

case $TIMESTAMP_OPT_VALUE in 
	all) 	
		SQL_FILTER=''
		;;
	today)  
		SQL_FILTER=''
		#SQL_FILTER="WHERE timestamp > <timestamp of 0:00 today>"
		;;
	yesterday)
		SQL_FILTER=''
                #SQL_FILTER="WHERE timestamp >= <timestamp of 0:00 yesterday> AND timestamp < <timestamp of 0:00 AM today>"
                ;;
	+*)
		SQL_FILTER="WHERE timestamp > ${TIMESTAMP_OPT_VALUE:1}"
		;;
	-*)
		SQL_FILTER="WHERE timestamp < ${TIMESTAMP_OPT_VALUE:1}"
                ;;
	*)
		SQL_FILTER=''
                #SQL_FILTER="WHERE timestamp > $(echo $$TIMESTAMP_OPT_VALUE | cut -f1 -d'-') AND timestamp < $(echo $$TIMESTAMP_OPT_VALUE | cut -f2 -d'-')"
		;;
esac
			

sqlite3 $DB_FILE "SELECT timestamp, hostname, latency FROM latency $SQL_FILTER;" | while read line;do
	echo -e "$(data_colorizer $(echo $line | tr '|' ' '))"
done
