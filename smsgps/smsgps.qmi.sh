#!/bin/sh
# script to read SMS mesages and send GPS cocordinates if requested 
# usage: script.name [num] Run at start up
#         num - 0 to 3: optional parameter for error logging
#
# Requirements: Install SOCAT on OpenWRT
# Installation:
#       Copy script to modem: scp /users/robert/documents/smsgps.sh root@192.168.8.1:/root/smsgps.sh
#       Copy Service (procd script) to modem: scp /users/robert/documents/smsgps root@192.168.8.1:/etc/init.d/smsgps
#       Copy Config file to modem: scp /users/robert/documents/smsgps.conf root@192.168.8.1:/etc/config/smsgps
#   Log into Router
#       chmod 755 /root/smsgps.sh
#       chmod 755 /etc/init.d/smsgps
#       /etc/init.d/smsgps enable
#       /etc/init.d/smsgps start
#
# Author: Robert Panizzon

# Modem Device
DEV=/dev/ttyUSB2
LOGLEVEL=0											# Default Log Level for reporting
SLEEP=60											# seconds to wait if initialisation fails
GPSTRACKER="trackgps"								# Script logs NMEA data

#GREP SMS Test
GREPPARM="^(0|1|2|3)$"								# Valid Input Parameters                 
GREPPHONE="\+\d{11}"								# Phone number of Message
GREPUNREAD="RECUNREAD"								# Unread Message
GREPTXT="gps"										# Text to find in SMS Text
GREPTRACK="starttrack"								# Text to turn on Tracking
GREPTRSTOP="stoptrack"								# Text stop Tracking
GREPGPS="(-|)\d+.\d{5},(-|)\d+.\d{5}"				# Pull out Longtitude and Latitude

# Send SMS Message
SMSPHONE="+61404111111"								# Default phone number
SMSPREFIX="https://www.google.com/maps?q="			# Prefix for SMS message to access Google Maps 
ATRESP="" 											# Response from atsend funtion

# Logging Routine
slog() {
	if [ $1 -ge $LOGLEVEL ]; then
		echo -e "${PROGNAME}: $2" 
	fi
}
# Send AT commands to modem and capture response
atsend() {
	ATLONG=$(echo -e $1 | socat - $DEV,crnl,echo=0)
	ATRESP=${ATLONG//[$'\r\n ']}
	if [ "$ATRESP" = "" ]; then
		ATRESP="***ERROR - No Response***"	
	fi
	slog 0 "Command: $1 > $ATRESP"
}
# Send and SMS Message
sendsms() {
	SMSPHONE=$(echo $MSG | grep $GREPPHONE -oE)		# Extract Phone Number    
	slog 2 "Sending SMS to: $SMSPHONE: Text: $1"
	atsend "AT+CMGS=\"$SMSPHONE\""
	atsend "$2$1\x1A"								# Send Message
	slog 0 "Message Sent"
}

# Initialize logging
PROGNAME=${0##*/}
if [ "$#" -ge 1 ]; then
	if [ $(echo $1 | grep -iE $GREPPARM ) ]; then
		LOGLEVEL=$1
		slog 2 "Log Level set to $LOGLEVEL"
	else
		slog 2 "Invalid Parameter - Ignored"
	fi
fi

# Initalize Modem
# stty --file=$DEV 9600 raw -echo -echoe -echok -echoctl -echoke

atsend "AT&F0"										# Reset Modem
while [ ! $(echo $ATRESP | grep -i "OK") ]
do
	slog 2 "SMS Modem not responding correctly> $ATRESP"
	sleep $SLEEP									# Wait a Minute and try again
	atsend "AT&F0"									# Keep trying to set echo off
done
slog 2 "SMS Modem ready"

atsend "ATE0"										# Turn off Echo
atsend "AT+QGPS=1"									# Turn on GPS just in case
atsend "AT+CMGF=1"									# set message format to text
atsend "AT+CSDH=1"									# set message List to show headers

atsend "AT+QNWINFO"
while [ ${ATRESP:0:2} = "No" ]; do					# Check for Carrier Service
	slog 1 "No Service - waiting for Network connection"
	sleep $SLEEP									# Wait a minute and try again
	atsend "AT+QNWINFO"
done

# Loop looking for SMS messages and responding to appropriate ones
while true
do
	atsend 'AT+CMGL="ALL"'							# Get SMS messages
	if [ "${ATRESP:0:3}" = "+CM" ]; then				# Check if we have one or more SMS Messages
		SMSMSGS=$(echo $ATRESP | awk '{gsub(/\+CMGL/, "\ \+CMGL")}1')	#Format Messages into lines
		for MSG in $SMSMSGS; do
			slog 0 "SMS Message> $MSG"			
			if [ ${MSG:0:5} = "+CMGL" ]; then		# Skip +CMTI record
				MSGNO=$(echo $MSG | awk -F'[:,]' '{print $2}')	# Delete message now in case
				slog 0 "Deleting Message number: $MSGNO"
				atsend "AT+CMGD=$MSGNO"					# Delete the SMS text message
				
				if [ $(echo $MSG | grep -i $GREPTRACK ) ]; then # Is Message to start GPSTRACKER
					slog 0 "SMS request to turn ON tracking"
					/etc/init.d/$GPSTRACKER restart
					sendsms "GPS Tracking Started"	
				elif [ $(echo $MSG | grep -i $GREPTRSTOP ) ]; then # Is Message to stop GPSTRACKER
					slog 0 "SMS request to turn OFF tracking"
					/etc/init.d/$GPSTRACKER stop
					sendsms "GPS Tracking Stopped"	
				elif [ $(echo $MSG | grep -i $GREPTXT ) ]; then	# Does Message contain the required text?
					slog 0 "SMS contains GPS request"               
					atsend "AT+QGPSLOC=2"				# get Get GPS
					if [ ${ATRESP:0:5} = "+QGPS" ]; then
						sendsms $(echo $ATRESP | grep -oE $GREPGPS ) $SMSPREFIX # Pull out Coordinates and send
					else
						slog 1 "Error in obtaining GPS"     
						sendsms "Location Failure"		# Default Set to Location Failure
					fi
				fi     	
			fi                                      
		done
	else
		slog 0 "Waiting for next SMS Message"
#		sleep 15
		read <$DEV -t 60
		slog 0 "We have a message: $REPLY"
	fi
done
#exit 0                                              # End of Script