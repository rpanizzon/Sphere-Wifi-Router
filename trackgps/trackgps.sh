#!/bin/sh
# script to read NMEA data and record it to GPX tracking file
#        script records any  location  after WPTTIME 
# usage: script.name [num]
#         num - 0 to 3: optional parameter for error logging
#
# Requirements: mailsend
# Installation:
#       Copy script to modem: scp /users/robert/documents/trackgps.sh root@192.168.8.1:/root/trackgps.sh
#       Copy Service (procd script) to modem: scp /users/robert/documents/trackgps root@192.168.8.1:/etc/init.d/trackgps
#   Log into Router
#       chmod 755 /root/trackgps.sh
#       chmod 755 /etc/init.d/trackgps
#       /etc/init.d/trackgps enable
#
#	You can start the service via smsgps. Send SMS to router with "Start Tracking"
#	You can stop the service via smsgps. Send SMS to router with "Stop Tracking"
#
# Author: Robert Panizzon

# Modem Device
DEV=/dev/ttyUSB1					# NMEA port
LOGLEVEL=2							# Default Log Level for reporting
GPXFILE="/root/track.gpx"			# File Name for Logging
GPXMAX=500000	    				# Maximum size of NMEA file before emailing it

# Tracking parameters
WPTTIME=80000						# Stationary time before writing Waypoint (Format: hhmmss)
MINDISTANCE=100						# Minimum distance for logging (metres)

# SMTP mailsend parameters
MAILFROM="trackgps@xxxx.com.au"		# Email address of sender - should match SMTP server name	
MAILTO="yyyyy@gmail.com"			# Email address of recipient
MAILSMTP="mail.xxxx.com.au"			# SMTP server to use for sending emails
MAILUSER="username"					# UserID used to log into SMTP server			
MAILPASS="password"					# Password of Userid to log into server

LASTTIME=0							# Last recorded Time
LASTLONG=0							# Last recorded Longitude
LASTLAT=0							# Last recorded Latitude

MINDIST=$(( $MINDISTANCE * 1000 / 111 )) # Minimum distance in degrees x 10^6
MINDISTSQ=$(( $MINDIST * $MINDIST )) 

#GREP validation
GRNTIME="[0-2][0-9][0-5][0-9][0-5][0-9].00"
GRNLAT="\d{4}.\d{6}"
GRNLONG="\d{5}.\d{6}"
GRNTFIX="(0\.|[^0]\d*\.)"

# Logging Routine
slog() {
	if [ $1 -ge $LOGLEVEL ]; then
		echo -e "${PROGNAME}: $2" 
	fi
}

# Modem Reader routine
readNMEA () {						# NMEA Read  - only read valid records
	while true; do					# Keep reading records until you have a trackpoint or waypoint
		while IFS=, read -u 3 NTYPE NTIME NLAT NNS NLONG NWE NQI NSV NHDOP NELE NREST
		do	
			if [ "$NTYPE" = "\$GPGGA" ] 	# Only process GPGGA records
			then
			# Validate Values NTIME NLAT and NLONG
			if [ $(echo $NTIME | grep -iE $GRNTIME ) ] &&
				[ $(echo $NLAT | grep -iE $GRNLAT ) ] &&
				[ $(echo $NLONG | grep -iE $GRNLONG ) ]
				then
					NTIMED=$( echo $NTIME | grep -oE $GRNTFIX | grep -oE "\d*" )	#Strip leading zeros and decimal point
# Need to convert to degrees from degrees minutes
					NLATALL=${NLAT//.}			#remove decimal point
					NLATDO=$(( ${NLATALL%????????} * 1000000 ))			# Degrees Only
					NLATD=$(( (${NLATALL%??} - $NLATDO) * 10 / 6 + $NLATDO )) 
					NLONGALL=${NLONG//.}		#remove decimal point
					NLONGDO=$(( ${NLONGALL%????????} * 1000000 ))		# Degrees Only
					NLONGD=$(( (${NLONGALL%??} - $NLONGDO) * 10 / 6 + $NLONGDO ))
# Calculate if we have moved more than $MINDIST				
					NLONGDA=$(( $NLONGD - $LASTLONG ))
					NLATDA=$(( $NLATD - $LASTLAT ))
					NDISTSQ=$(( ($NLONGDA * $NLONGDA ) + ($NLATDA * $NLATDA) ))
					if [ $NDISTSQ -ge $MINDISTSQ ] ; then
						slog 0 "Distance exceeded: $NDISTSQ > $MINDISTSQ"
						slog 0 "                 : $NLATDA ($NLATD - $LASTLAT > $MINDIST)"
						slog 0 "                 : $NLONGDA ($NLONGD - $LASTLONG > $MINDIST)"
						notmoving=false
						return				#return to main routine
					fi
# If we are in a waypoint, keep looping until we move
					if $notmoving; then
						break
					fi
# Check if we have not moved for $WPTTIME				
					NTIMEDA=$(( $NTIMED - $LASTTIME ))
					if [ $NTIMEDA -lt 0 ]; then
						NTIMEDA=$(( $NTIMEDA + 240000 ))		# crossed over to another day
					fi
					if [ $NTIMEDA -ge $WPTTIME ]; then			# Waypoint Detected
						slog 0 "Waypoint: $NTIMEDA ($NTIMED - $LASTTIME > $WPTTIME)"
						notmoving=true	# Flag we are at waypoint					
						return
					fi
				fi
			fi
		done
	done
}	

emailfiles() {							# Email all outstanding Log Files
	slog 0 "Emailing all outstanding GPX files"
	for ENTRY in ${GPXFILE%.*}.*.gpx
	do
		D=${ENTRY:(-16):12}				# Extract date and time of archived file
		MAILSUB="GPS tracking data ending: ${D:6:2}-${D:4:2}-${D:0:4} ${D:8:2}:${D:(-2)}"
		#mail out file
		mailsend -f $MAILFROM -t $MAILTO -sub "$MAILSUB" \
        	-smtp $MAILSMTP -auth -user $MAILUSER -pass $MAILPASS \
        	-mime-type "text/plain" -attach "$ENTRY"
		if [ "$?" = "0" ]; then
			slog 2 "GPX file $ENTRY emailed - deleting file"
			rm $ENTRY
		else
			slog 2 "Emailing GPX file $ENTRY failed - exit"
			return 1
		fi
	done
}

writeWPT() {							# Write GPX Waypoint record
	slog 0 "Write Waypoint record"	
	wrtType "<wpt"						# write Waypoint Record
	echo -e "   <name>Waypoint $( date -u +%d-%m-%Y )</name>\n</wpt>" >>$GPXFILE # Write name		
	notmoving=true						# Flag we are in a waypoint
}

writeTRK() {							# Write GPX tracking record
	slog 0 "Write Track record"
	wrtType "  <trkpt"
	echo -e "  </trkpt>" >> $GPXFILE
	notmoving=false						# Flag we are in a moving	
}

wrtType() {								# Write GPX location
	slog 0 "Write $1 GPX record"
	echo -e "$1 lat=\"-${NLATD%??????}.${NLATD: -6}\" lon=\"${NLONGD%??????}.${NLONGD: -6}\">" >> $GPXFILE
	echo -e "   <ele>$NELE</ele>" >> $GPXFILE						# Write Elevation
	echo -e "   <time>$( date -u +%Y-%m-%dT%TZ )</time>" >>$GPXFILE 	# Write Date and Time
	echo -e "   <sat>$NSV</sat>\n   <hdop>$NHDOP</hdop>" >> $GPXFILE
	LASTLONG=$NLONGD					# Record last written longitude
	LASTLAT=$NLATD						# Record last written latitude
	LASTTIME=$NTIMED					# Record last written time
}

# Main Program
PROGNAME=${0##*/}						# Get Program Name
exec 3< $DEV							# Set up file descriptor

if [ "$#" -ge 1 ]; then					# Initialise Logging level if there is a parameter
	if [ $(echo $1 | grep -iE "^(0|1|2|3)$" ) ]; then
		LOGLEVEL=$1
		slog 2 "Log Level set to $LOGLEVEL"
	else
		slog 2 "Invalid Parameter - Ignored"
	fi
fi

# sleep 60									# Wait for Router to initialise
slog 2 "Task Started"

readNMEA									# Read first record

while true; do    								# Main Loop
	if [ -f $GPXFILE ]; then				# Check if GPX file exits
		slog 2 "Closing GPX Tracking FIle"	# Close existing Log file and email it
		echo -e " </trkseg>\n</trk>\n</gpx>"  >> $GPXFILE	
		mv "$GPXFILE" "${GPXFILE%.*}.$( date +%Y%m%d%H%M ).gpx" 	# Rename File
		emailfiles							# Email out files
	fi

	# Start a new GPX file
	slog 0 "Start new GPX file"
	echo '<?xml version="1.0" encoding="utf-8" standalone="yes"?>' > $GPXFILE
	echo '<gpx version="1.1" creator="'$PROGNAME'">' >> $GPXFILE
	slog 2 "GPS Tracking Started"

	while true ; do							# Waypoint Loop
		writeWPT 
		echo -e "<trk>\n <name>Segment $( date -u +%d-%m-%Y )</name>\n <trkseg>"  >> $GPXFILE	# Start new segment
		
		FILESIZE=$( wc -c $GPXFILE| awk '{print $1}' )	# check file size
		if [ $FILESIZE -gt $GPXMAX ]; then
			break							# Close off GPX and start a new
		fi
				
		readNMEA							# Read next record after waypoint

		while true ; do						# We are moving - record track segment
			writeTRK		
			readNMEA
			if $notmoving ; then			# Detected we are at a waypoint
				echo -e " </trkseg>\n</trk>"  >> $GPXFILE	# Close off Track segment
				break
			fi
		done
	done
done
# exit 0                                  # End of Script
