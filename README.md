The Sphere Mobile WiFi Router with GPS is a mobile router distributed in Australia by "Coast to Coast RV" (Product Code: 900-09102). The router is used extensively in mobile homes and caravans. Unfortunately, the router runs a very old version of OpenWRT that has been heavily customised.

This project is to upgrade the firmware of the router to OpenWRT release V21.02.2 or better and add a number of useful features such as GPS location and GPS Tracking.
Familiarity with OpenWRT and networking is assumed. **Do not attempt to upgrade the router unless you know what you are doing.** If you brick the Router, look to the Openwrt documentation to help - **I can't help you**.

# Hardware
The device is essentially a [ZBT WE-826](https://openwrt.org/toh/hwdata/zbt/zbt_we826t_16m) router with 16M memory fitted with a [Quectel EC25 mPCIe module](https://www.quectel.com/product/lte-ec25-mini-pcie-series) which provides GSM and GPS support. The device has 1 WAN, 4 LAN ports and 1 USB connection.
# Firmware download and installation
This installation of OpenWRT on Sphere router (WE-826t) uses [QMI protocol](https://openwrt.org/docs/guide-user/network/wan/wwan/ltedongle) to communicate with the EC25. I also have a version based on mbin protocol but, in my opinion, it does not work as well as qmi protocol.
## Obtaining the Firmware
You have 3 ways of obtaining the firmware: 
1. 	Download the latest release from OpenWRT [here](https://openwrt.org/toh/zbtlink/we-826). Use the "T 16M" version. Note, this will require installation of additional packages later (see below).
2.	Use the firmware provided in this repository. Note this is V21.02.2 and **is the version I have tested everything on**.
3.	**(Preferred)** Build a customised version of the firmware with all required modules (this produces the fastest and smallest firmware).
	1.	Go to [OpenWRT Firmware Selector Tool](http://firmware-selector.openwrt.org/)
	2.	Enter the name and model: `Zbtlink ZBT-WE826 16M` and select the desired release level (21.02.2 or better)
	3.	Select `Customize installed packages` and add:
		- `kmod-usb-net-rndis usb-modeswitch usb-modeswitch kmod-mii kmod-usb-net kmod-usb-wdm kmod-usb-net-qmi-wwan uqmi kmod-usb-serial-option kmod-usb-serial kmod-usb-serial-wwan luci-proto-qmi socat mailsend`
		- Optionally also add: `travelmate luci-app-travelmate mwan3 luci-app-mwan3` (see below)
		- Some additional useful debugging packages you may also wish to include: `minicom openssh-sftp-server`		
	4.	Select `Request Build` and wait for the build to finish (hopefully without errors).
	5.	Select `Sysupgrade` to download the Firmware to your PC
## Flashing the Firmware
A wired connection is advisable. Login into the router. Default IP is `192.168.8.1`. Default password is `admin` (but hopefully you've changed it 😉).
Go to `SYSTEM` > `System Tools` and download and install the firmware. This takes some time.
# Configuring Router
If you used option 1 to obtain the firmware, you <ins>will</ins> need to connect the router to the internet via the WAN port. It is strongly recommended that you connect your PC via the LAN port.
## System Setup
1.	Log into OpenWRT for the first time (http://192.168.1.1/) - password is blank
2.	Got to `System` and update `Hostname`, and `Time`
3.	Got to `Administration` and change router password
4.	Got to `Network` > `LAN` and change DHCP to `192.168.8.1` (default IP address on the previous firmware) and `Apply`
5.	Log back in with new IP address (192.168.8.1) na new password. Note you will need to renew your IP on your PC and log in before the timeout rolls back the change.
6.	Update the wireless network: `Network` > `Wireless` > `Edit Master`
	- 	I recommend that you change the `ESSID` and Wireless Security. Also change `Country Code` under `Advance Settings`
	-  	`Enable`, `Save` and `Apply`
## Install LTE modem in QMI mode
Follow the process outlined below basically follows the instructions from [OpenWRT Guide here](https://openwrt.org/docs/guide-user/network/wan/wwan/ltedongle)
1.	If you installed the firmware using option 1 above then you will need to install a number of modules. The simplest way to do this is via Terminal session
	-	Start Terminal session – `ssh root@192.168.8.1` Once logged in issue the following commands:
		-	`opkg update`
 		-	`opkg install usb-modeswitch kmod-mii kmod-usb-net kmod-usb-wdm kmod-usb-net-qmi-wwan uqmi`
		-	`opkg install kmod-usb-serial-option kmod-usb-serial kmod-usb-serial-wwan`
		-	`opkg install luci-proto-qmi`
		-	`Reboot`
	-	Check everything is okay (optional):
		-	Log back into router with SSH
		- 	issue following command to confirm device is connected: `ls -l /dev/cdc-wdm0`
2.	Log into the router from your browser (192.168.8.1) 
3.	Configure the modem using LuCi:  `Network` > `Interfaces`			i.	
	-	Add new interface (e.g. GSM), Protocol: `QMI Cellular`
	-	General Setting: Modem Device: `/dev/cdc-wdm0`, APN: (as specified by your network provider), PDP Type: `IPv4`
	-	Firewall Setting: `WAN`
	-	`Save` and `Apply`
Your GSM interface should now be working.	
## Install Cellular Network Info
If you wish to install a module to provide Information about Cellular network strength follow the process as outlined [here](https://forum.openwrt.org/t/cellular-signal-level-indicator/60543/18). 
1.	Download LuCi program from [here](http://www.rottengatter.de/download/luci-app-qmi-cellstatus_1.0.0_all.ipk)
2.	Copy to the router: `scp ./luci-app-qmi-cellstatus_1.0.0_all.ipk root@192.168.8.1:/root`
3.	Log into router via ssh and install using the following command: `opkg install ./luci-app-qmi-cellstatus_1.0.0_all.ipk`
4.	Restart LuCi interface: `/etc/init.d/uhttpd restart`

# Optional Installations
## Install iPhone Support:
If you want to tether your iPhone via the USB interface, follow the following instructions which are from [here](https://openwrt.org/docs/guide-user/network/wan/smartphone.usb.tethering?s[]=iphone)
1.	Start Terminal session – `ssh root@192.168.8.1`. Once logged in issue the following commands:
	-	If you installed the firmware using option 1 above: 
		-	`opkg update`
		-	`opkg install kmod-usb-net-ipheth usbmuxd libimobiledevice usbutils`
	-	`usbmuxd -v`  				# Call usbmuxd
	-	`sed -i -e "\$i usbmuxd" /etc/rc.local`	# Add usbmuxd to autostart
4.	Plug in iPhone, and confirm Trust: `Yes`
5.	Define iPhone interface through LuCi:
	1.	Log into Web interface
	2.	`Network` > `Interfaces`  click on `Add New Interface`
		- 	`General Settings` > `Name: iPhone`; `Protocol: "DHCP Client"`; `Device: "eth1"`
		-	`Firewall Settings: Assign: "wan"`
## Travelmate
The Travelmate package is a wlan connection manager for travel routers. Travelmate provides a number of useful features to connect to a local wlan as an alternative to using your GSM connection (WiFi extender). Travelmate documentation and installation instructions can be found [here](https://forum.openwrt.org/t/travelmate-support-thread/5155)
If you used option 1 or did not include the Travelmate package, when customising the install package (option 3), then you will need to install Travelmate. You can do this vis the browser interface (LuCi): `System` > `Software`
Search for “travelmate” and install `travelmate` and `luci-app-travelmate`. Then `Reboot` and follow the instructions above.
## MWAN3			
The mwan3 package provides outbound WAN traffic load balancing or fail-over with multiple WAN interfaces. It can monitor wan, gsm and wifi extended internet connections, providing policy based routing. 
Mwan3 documentation and installation instructions can be found [here](https://openwrt.org/docs/guide-user/network/wan/multiwan/mwan3). It is beyond the scope of this document to provide mwan3 parameters, but the instructions above are pretty clear.
If you used option 1 or did not include the mwan3 package, when customising the install package (option 3), then you will need to install mwan3. You can do this vis the browser interface (LuCi): `System` > `Software`
Search for “travelmate” and install `mwan3` and `luci-app-mwan3`. Then `Reboot` and follow the instructions above.
# GPS
I've developed a couple of shell scripts to provide GPS information.		
## SMS GPS script (smsgps.sh)
smsgps is a script that provides GPS coordinates of the location of the router (caravan or mobile home) by sending an SMS message to the router. 
To obtain GPS coordinates:
-	From a mobile phone send the SMS message `GPS` to the mobile number of the SIM installed in the router.
-	Within a few seconds the router will respond via SMS with a google maps link with coordinates.
-	Clicking the SMS response will display the location of the router (caravan or mobile home) in Google Maps.
### Installation Instructions
1.	If you installed the firmware using option 1 above then you will need to install the `socat` module. Install required coreutil via browser interface (LuCi): 'System' > 'Software'. Install 'socat'
2.	Using Terminal (or similar program):
	- 	Change directory to * *Repository* */smsgps
	- 	Copy script to router `scp ./smsgps.qmi.sh root@192.168.8.1:/root/smsgps.sh`
	- 	Copy Service (procd script) to router `scp ./smsgps root@192.168.8.1:/etc/init.d/smsgps`
	- 	Copy Config file to router `scp ./smsgps.conf root@192.168.8.1:/etc/config/smsgps`
3.	Log into Router via SSH and issue the following commands
	-	`chmod 755 /root/smsgps.sh` 	# set access level
	-	`chmod 755 /etc/init.d/smsgps`	# set access level
	-	`/etc/init.d/smsgps enable`		# initialise as a started task
	-	`/etc/init.d/smsgps start`		# Start the script
## GPS tracking script (trackgps.sh)
Trackgps is a script that tracks the movement of the router (motor home or caravan) and produces a GPX file that can be displayed via Google Maps of a similar program (e.g. GPXsee). The user has an accurate record of their journey, including location, path, time elevation and waypoints.
TrackGPX emails the GPX file when larger than a specified size or when when the router boots or via a command (see below).
Trackgps can be:
-	stopped by sending the SMS message `stop tracking` to the mobile number of the SIM in the router  
-	(re)started by sending the SMS message `start tracking` to the mobile number of the SIM in the router. Note that this will force the script to close the current GPX file and email it to the specified email address.
### Installation instructions
1.	If you installed the firmware using option 1 above then you will need to install the `mailsend` module. Install required coreutil via browser interface (LuCi): 'System' > 'Software'. Install 'mailsend'
2. Prior to installing the script, you will need to update the script with SMTP mailsend parameters. Edit the trackgps.sh script updating the following variables:
	-	`MAILFROM="trackgps@xxxx.com.au"`	# Email address of sender - should match SMTP server name	
	-	`MAILTO="yyyyy@gmail.com"`			# Email address of recipient
	-	`MAILSMTP="mail.xxxx.com.au"`		# SMTP server to use for sending emails
	-	`MAILUSER="username"`				# UserID used to log into SMTP server			
	-	`MAILPASS="password"`				# Password of Userid to log into server
3.	Using Terminal (or similar program):
	- 	Change directory to * *Repository* */trackgps
	- 	Copy script to router: `scp ./trackgps.qmi.sh root@192.168.8.1:/root/trackgps.sh`
	-	Copy Service (procd script) to router: `scp ./trackgps root@192.168.8.1:/etc/init.d/trackgps`
4.	Log into Router via SSH and issue the following commands
	-	`chmod 755 /root/trackgps.sh` 		# set access level
	-	`chmod 755 /etc/init.d/trackgps`	# set access level
	-	`/etc/init.d/trackgps enable`		# initialise as a started task
	-	`/etc/init.d/reackgps start`		# Start the script
# Appendix
## Some Useful Commands
-	AT+QCFG="usbnet"   - shows current mode
-	AT+QCFG="usbnet",0 - is PPP & QMI (default)
-	AT+QCFG="usbnet",1 - is ECM
-	AT+QCFG="usbnet",2 - is MBIM
-	AT+CFUN=1,1        - reboot QE25
-	uqmi -d /dev/cdc-wdm0 --get-data-status  - QMI status
-	/etc/init.d/uhttpd restart  - restart LuCi
## Restore
If you want to restore the router to the original firmware, you can try flashing the firmware located in the repository (V2.8.4.1.bin). 
I haven't tried this.
		
		
