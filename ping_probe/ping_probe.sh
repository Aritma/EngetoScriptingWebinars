#!/bin/bash

# TODO: Add config file existence check and default value implementation
# TODO: Implement valid execution path separation to handle exectuin from different locations

source ./pp_config.cfg

# FCE NAME: print_msg
# AGRS: All arguments are passed to echo as string
# DESCRIPTION: Prints input in stdout if PRINT_TO_STDOUT config value is valid
function print_msg () {
	if [[ "$PRINT_TO_STDOUT" =~ true|True|TRUE|1|yes|YES|Yes ]];then
		echo "$@"
	fi
}


# FCE NAME: get_ping_output
# ARGS: Hostname of target server
# DESCTRIPTION: Returns ping output in formated "One-line" version
# RETURN: Function returns following exit codes:
# NOTE: Pings longer then LATENCY_LIMIT_SECONDS will be resolved as timed out.
#	  0 - no problem
#	  124 - timed out
#	  other - other errors
function get_ping_line () {
	timeout $(($PING_SAMPLE_COUNT * $LATENCY_LIMIT_SECONDS + 2)) ping -c $PING_SAMPLE_COUNT $1 2> /dev/null | xargs
	return ${PIPESTATUS[0]}
}


# FCE NAME: get_average_ping
# AGRS: Hostname of target server
# DESCRIPTION: Pings server defined in argument. Number of samples eaquals PING_SAMPLE_COUNT value in config file.
#	       Prints average latency (counted without min and max value) in miliseconds with two decimals.
# RETURN: Returns 0 if value is returned and 124 on timeout and 1 on error
function get_average_ping () {
	PING_LINE="$(get_ping_line $1)"
	PING_EXIT=$?
	if [[ $PING_EXIT -eq 0 ]];then
		bc_arg=$(echo "$PING_LINE" | tr ' ' '\n' | grep 'time=' | cut -f2 -d'=' | sort -n | sed '1d; $d' | xargs | tr ' ' '+')
		avg_latency=$(bc <<< "scale=2;(${bc_arg})/($PING_SAMPLE_COUNT-2)")
	elif [[ $PING_EXIT -eq 124 ]];then
		return 124
	else
		return 1
	fi
	if [[ "$avg_latency" =~ ^\. ]];then
		echo "0$avg_latency"
	else
		echo $avg_latency
	fi
	return 0
}


# MAIN BLOCK
print_msg "Ping probe initiated. Waiting for results..."
cat $HOSTS_LIST_FILE | {
	while read line;do
		avg_latency=$(get_average_ping $line)
		AVG_PING_EXIT=$?
		if [[ $AVG_PING_EXIT -eq 0 ]];then
			sqlite3 $DB_FILE "INSERT INTO latency (timestamp, hostname, latency) VALUES ($(date +%s), \"$line\", $avg_latency);"
			print_msg "$line: $avg_latency ms"
		elif [[ $AVG_PING_EXIT -eq 124 ]];then
			sqlite3 $DB_FILE "INSERT INTO latency (timestamp, hostname, latency) VALUES ($(date +%s), \"$line\", -99);"
			print_msg "$line: Timeout"
		else
			sqlite3 $DB_FILE "INSERT INTO latency (timestamp, hostname, latency) VALUES ($(date +%s), \"$line\", -1);"
			print_msg "$line: Error"
		fi
	done 
}
print_msg "Ping probe finished."
