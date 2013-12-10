#!/usr/local/bin/bash

# Define TRUE and FALSE
TRUE=0
FALSE=1

# Store options selected by user
F_MENU=./.menu.tmp
F_INPUT=./.in.tmp
F_OUTPUT=./.out.tmp
F_IF=./.if.tmp
F_ERROR=./error.log
F_STATUS=./.status.tmp
F_STATUS_DISP=./.status.disp.tmp

# Title and message
BACKTITLE="IP Configuration Tool"
TITLE_MAIN="[ M A I N - M E N U ]"
TITLE_STATUS="[ S T A T U S ]"
TITLE_MANUAL="[ M A N U A L - S E T U P ]"
TITLE_IF="[ I N T E R F A C E - S E T U P ]"
TITLE_GW="[ G A T E W A Y - S E T U P ]"
TITLE_DHCP="[ D H C P - S E T U P ]"
MENU_MSG="You can use the UP/DOWN arrow keys, the first \
letter of the choice as a hot key, or the \
number keys 1-9 to choose an option.\\n\
Choose the TASK"

# Menu dimension
HEIGHT=15
WIDTH=50

# Default value
interface=""
ip_addr=""
netmask=""
str_netmask=""
gateway=""

#######################################################
#                    MESSAGE BOX                      #
#######################################################
# Display message using msgbox 
# $1 -> title
# $2 -> message
# $3 -> height
# $4 -> width
function display_msg(){
	dialog --backtitle "$BACKTITLE" --title "$1"\
		--clear --msgbox "$2" $3 $4
}
#######################################################

#######################################################
#                     INPUT BOX                       #
#######################################################
# Display input box
# $1 title
# $2 input description
function display_if_input_box(){
	local ret
	while true; do
		dialog --title "$1" \
			--backtitle "$BACKTITLE" \
			--nocancel \
			--inputbox "$2" 8 60 2>$F_OUTPUT

		ret=$?
		case $ret in
		0) check_interface && interface=$(<$F_OUTPUT) || interface=""
			break;
			;;
		*) break;
		esac	
	done

	return $TRUE;
}

# $1 -> title
# $2 -> input description
function display_ip_input_box(){
	local ret
	while true; do
		dialog --title "$1" \
			--backtitle "$BACKTITLE" \
			--nocancel \
			--inputbox "$2" 8 60 2>$F_OUTPUT

		ret=$?
		case $ret in
		0) check_ip && ip_addr=$(<$F_OUTPUT) || ip_addr=""
			break; ;;
		*) break;
		esac	
	done

	return $TRUE;
}

# $1 -> title
# $2 -> input description
function display_netmask_input_box(){
	local ret
	while true; do
		dialog --title "$1" \
			--backtitle "$BACKTITLE" \
			--nocancel \
			--inputbox "$2" 8 60 2>$F_OUTPUT

		ret=$?
		case $ret in
		0) check_netmask && netmask=$(<$F_OUTPUT) || netmask=""
			break; ;;
		*) break;
		esac	
	done

	return $TRUE;
}

# $1 -> title
# $2 -> input description
function display_gateway_input_box(){
	local ret
	while true; do
		dialog --title "$1" \
			--backtitle "$BACKTITLE" \
			--nocancel \
			--inputbox "$2" 8 60 2>$F_OUTPUT

		ret=$?
		case $ret in
		0) check_gateway && gateway=$(<$F_OUTPUT) || gateway=""
			break; ;;
		*) break;
		esac	
	done

	return $TRUE;
}
#######################################################

#######################################################
#                        MENU                         #
#######################################################
# Display menu
function display_interface_select_menu(){
	local loop=0
	local str=`for iface in $(<$F_IF); do loop=$(($loop+1)); echo $iface No.$loop; done`
	while true; do
		dialog --clear  --help-button --backtitle "$BACKTITLE" \
			--title "$TITLE_IF" \
			--menu "$MENU_MSG" 15 50 $(($TOTAL_IF+1)) \
			$str \
			Exit "Exit to main menu" 2>"$F_MENU"

		menuitem=$(<"$F_MENU")

		# make decsion 
		case $menuitem in
		Exit) break; ;;
		*)  for iface in $(<$F_IF); do
				if [ "$iface" = "$menuitem" ]; then
					interface=$iface
				fi
			done

			if [ "$1" = "config" ]; then
				display_config_menu;
			else
				display_gateway_config_menu;
			fi
			break;
		esac
	done

	return $TRUE;
}

function display_config_menu(){
	while true; do
		dialog --clear  --help-button --backtitle "$BACKTITLE" \
			--title "$TITLE_IF" \
			--menu "$MENU_MSG" 15 60 3 \
			Manual "Manual configure IP, Netmask" \
			DHCP "Get IP, Netmask and Gateway from DHCP server" \
			Exit "Exit to main menu" 2>"$F_MENU"

		menuitem=$(<"$F_MENU")

		# make decsion 
		case $menuitem in
		Manual) display_manual_config_menu;;
		DHCP) set_dhcp; status2file;;
		Exit) break;
		esac
	done

	return $TRUE;
}

function display_manual_config_menu(){
	ip_addr=`cat $F_STATUS | grep $interface | awk '{print $2}'`
	netmask=`cat $F_STATUS | grep $interface | awk '{print $3}'`
	str_netmask=$netmask
	while true; do
		dialog --clear  --help-button --backtitle "$BACKTITLE" \
			--title "$TITLE_MANUAL" \
			--menu "$MENU_MSG" 15 50 4 \
			IP "Setup IP Address: $ip_addr" \
			Netmask "Setup Netmask: $str_netmask" \
			Setup "Configuration Start" \
			Exit "Exit to main menu" 2>"$F_MENU"

		menuitem=$(<"$F_MENU")

		# make decsion 
		case $menuitem in
#		Interface) display_if_input_box "Interface" \
#			"Input interface name($IF) and press ENTER to \
#submit, or press ESC to leave."; ;;

		IP) display_ip_input_box "IP Address" \
			"Input IP address and press ENTER to submit, \
or press ESC to leave.";;

		Netmask) display_netmask_input_box "Netmask" \
			"Input netmask and press ENTER to submit, \
or press ESC to leave."
			if [ -z $netmask ]; then
				str_netmask="Default"
			else
				str_netmask=$netmask
			fi
			;;

		Setup) set_ip; status2file ;;

		Exit) break;
		esac
	done

	return $TRUE;
}

function display_gateway_config_menu(){
	gateway=`cat $F_STATUS | grep DEFAULT | awk '{print $2}'`
	while true; do
		dialog --clear  --help-button --backtitle "$BACKTITLE" \
			--title "$TITLE_GW" \
			--menu "$MENU_MSG" 15 50 4 \
			Gateway "Setup Gateway: $gateway" \
			Setup "$result" \
			Exit "Exit to main menu" 2>"$F_MENU"

		menuitem=$(<"$F_MENU")

		# make decsion 
		case $menuitem in
#		Interface) display_if_input_box "Interface" \
#			"Input interface name($IF) and press ENTER to \
#submit, or press ESC to leave."; ;;

		Gateway) display_gateway_input_box "Gateway" \
			"Input gateway and press ENTER to submit, \
or press ESC to leave.";;

		Setup) set_gateway; status2file ;;

		Exit) break;
		esac
	done
	return $TRUE;
}

#function display_dhcp_config_menu(){
#	while true; do
#		dialog --clear  --help-button --backtitle "$BACKTITLE" \
#			--title "$TITLE_DHCP" \
#			--menu "$MENU_MSG" 15 50 3 \
#			Interface "Select Interface: $interface" \
#			Setup "$result" \
#			Exit "Exit to main menu" 2>"$F_MENU"
#
#		menuitem=$(<"$F_MENU")
#
#		# make decsion 
#		case $menuitem in
#		Interface) display_if_input_box "Interface" \
#			"Input interface name($IF) and press ENTER to \
#submit, or press ESC to leave."; ;;
#
#		Setup) set_dhcp ;;
#
#		Exit) break;
#		esac
#	done
#	return $TRUE;
#}
#######################################################

# Parsing if/ip/netmask/default gw/status to config file
# config file format: 
# interface      ip          netmask       status
#   igb0    192.168.1.1   255.255.255.0  no carrier 
#   ...         ...            ...         active
# default_gw 192.168.1.254 
function status2file(){
	local ip=""
	local nm=""
	local nms=""
	local sta=""

	# remove exist file
	if [ -e $F_STATUS ]; then
		rm -rf $F_STATUS
	fi

	printf "INTERFACE       IP_ADDRESS          NETMASK       STATUS\n" > $F_STATUS
	printf "INTERFACE       IP_ADDRESS          NETMASK       STATUS\\\n" > $F_STATUS_DISP
	for iface in $(<$F_IF); do
		ip=`ifconfig $iface | grep inet | awk '{print $2}'`

		if [ -z $ip ]; then
			ip="none"
		fi

		nms=`ifconfig $iface | grep netmask | awk '{print $4}' | sed 's/0x//g'`

		if [ ${#nms} -ne 8 ] && [ -n "$nms" ];then
			nms=0$nms
		fi

		nms=(`echo $nms | sed 's/../ &/g' | tr '[:lower:]' '[:upper:]'`)

		if [ -z "$nms" ]; then
			nm="none"
		else
			for i in 0 1 2 3; do
				nms[$i]=`echo "ibase=16; ${nms[$i]}" | bc`
				i=$(($i+1))
			done
			nm=${nms[0]}.${nms[1]}.${nms[2]}.${nms[3]}
		fi

		sta=`ifconfig $iface | grep status | awk -F": " '{print $2}'`
		if [ "$sta" != "active" ]; then
			sta="no_carrier"
		fi

		printf '%9s%17s%17s%13s\n' $iface $ip $nm $sta >> $F_STATUS 
		printf '%9s%17s%17s%15s' $iface $ip $nm $sta\\n >> $F_STATUS_DISP 
	done

		printf "\nDEFAULT_GW: `netstat -rn | grep default | awk '{print $2}'` \n" >> $F_STATUS
		printf "\\\nDEFAULT_GW: `netstat -rn | grep default | awk '{print $2}'`" >> $F_STATUS_DISP
}

# Show configuration result
function show_config_result(){
	if [ $1 -eq 1 ]; then
		# Should not happened
		display_msg "Error" "$(<$F_ERROR)" 10 50
		return $FALSE;
	else
		display_msg "Configuration Result" "SUCCESS!" 5 30
		return $TRUE;
	fi
}

# Parsing the interface name and write into file
function scan_interface(){
	TOTAL_IF=0
	IF=`ifconfig | grep flags | awk -F":" '{print $1}' | sed /lo0/d | sed /member/d`
	for iface in $IF; do
		TOTAL_IF=$(($TOTAL_IF+1))
		echo -n "$iface " >> $F_IF
	done
	IF=$(<$F_IF)
}

# Make sure the interface is legal
function check_interface(){
#	IF=`ifconfig | grep flags | awk -F":" '{print $1}' | sed /lo0/d`
	
	for iface in $(<$F_IF); do
		if [ "$iface" = "$(<$F_OUTPUT)" ]; then
			return $TRUE;
		fi
	done

	display_msg "Error" "Incorrect interface name" 5 30
	return $FALSE;
}

# make sure the ip address is legal
function check_ip(){
	local count255=0
	local count0=0
	local total=0
	if [ -z $(<$F_OUTPUT) ]; then
		display_msg "Error" "IP address is empty." 5 30
		return $FALSE;
	fi
	
	if [ -z $interface ]; then
		display_msg "Error" "Interface is empty, please setup interface first." 5 60
		return $FALSE;
	fi

	# the number should not greater than 255 or less than 0
	for number in `echo $(<$F_OUTPUT) | tr '.' ' '`; do
		total=$(($total+1))
		if [ $number -gt 255 ] || [ $number -le -1 ]; then
			display_msg "Error" "Illegal IP address." 5 30
			return $FALSE;
		fi

		if [[ ($total -eq 1 || $total -eq 4) && ($number -eq 0) ]]; then
			count0=$(($count0+1))
		fi

		if [ $number -eq 255 ]; then
			count255=$(($count255+1))
		fi
	done

	# check if ip address already exist
	if [ $(<$F_OUTPUT) != "0.0.0.0" ]; then
		if [ $count255 -eq 4 ] || [ $total -ne 4 ] || [ $count0 -eq 2 ]; then
			display_msg "Error" "Illegal IP address." 5 60
			return $FALSE;	
		fi

		IF=$(<$F_IF)
	
		for iface in $IF; do
			# only compare ip address to the other interface
			if [ "$iface" != "$interface" ]; then
				IP=`ifconfig $iface | grep inet | awk '{print $2}'`
				if [ "$IP" == "$(<$F_OUTPUT)" ]; then
					display_msg "Error" "$(<$F_OUTPUT) already exist." 5 30
					return $FALSE;
				fi
			fi
		done
	fi

	return $TRUE;
}	

function check_netmask(){
	local count255=0
	local total=0	

	if [ -z $ip_addr ]; then
		display_msg "Error" "IP address is empty." 5 30
		return $FALSE;
	fi
	
	if [ -z $interface ]; then
		display_msg "Error" "Interface is empty, please setup interface first." 5 60
		return $FALSE;
	fi

	if [ -z $(<$F_OUTPUT) ]; then
		display_msg "" "Use default netmask." 5 30
		return $TRUE;
	fi

	for number in `echo $(<$F_OUTPUT) | tr '.' ' '`; do
		total=$(($total+1))	
		if [ $number -gt 255 ] || [ $number -le -1 ]; then
			display_msg "Error" "Illegal netmask." 5 30
			return $FALSE;
		fi

		if [ $number -eq 255 ]; then
			count255=$(($count255+1))
		fi
	done

	if [ $count255 -eq 4 ] || [ $total -ne 4 ]; then
		display_msg "Error" "Illegal netmask." 5 30
		return $FALSE;
	fi

	return $TRUE;
}

function set_ip(){
	if [ -z $interface ]; then
		display_msg "Error" "Interface is empty, please setup interface first." 5 60
		return $FALSE;
	fi

	if [ -z $ip_addr ]; then
		display_msg "Error" "IP address is empty." 5 30
		return $FALSE;
	fi

	# kill dhclient before ifconfig
	killall dhclient >& /dev/null

	if [ -z $netmask ]; then
		ifconfig $interface $ip_addr >& $F_ERROR
	else
		ifconfig $interface $ip_addr netmask $netmask >& $F_ERROR
	fi

	# should not happened
	show_config_result $? && return $TRUE || retrun $FALSE
}

function check_gateway(){
	local count255=0
	local total=0

	if [ -z $(<$F_OUTPUT) ]; then
		display_msg "Error" "Gateway is empty." 5 30
		return $FALSE;
	fi

	for number in `echo $(<$F_OUTPUT) | tr '.' ' '`; do
		total=$(($total+1))	
		if [ $number -gt 255 ] || [ $number -le -1 ]; then
			display_msg "Error" "Illegal gateway." 5 30
			return $FALSE;
		fi

		if [ $number -eq 255 ]; then
			count255=$(($count255+1))
		fi
	done

	if [ $count255 -eq 4 ] || [ $total -ne 4 ]; then
		display_msg "Error" "Illegal gateway." 5 30
		return $FALSE;
	fi

	return $TRUE;
}

function set_gateway(){
	route add default $gateway >& $F_ERROR
	show_config_result $? && return $TRUE || return $FALSE
}

function set_dhcp(){
	if [ -z $interface ]; then
		display_msg "Error" "Interface is empty, please setup interface first." 5 60
		return $FALSE;
	fi

	# kill dhcpclient
	killall dhclient >& /dev/null
	dhclient $interface >& $F_ERROR
	show_config_result $? && return $TRUE || return $FALSE
}

# Delete temp file
function delete_temp(){
	rm -rf .*.tmp
}

# main
delete_temp
scan_interface
status2file

# set infinite loop
while true; do
# display main menu
	dialog --clear  --help-button --backtitle "$BACKTITLE" \
		--title "$TITLE_MAIN" \
		--menu "$MENU_MSG" $HEIGHT $WIDTH 4 \
		Status "Display status" \
		Configure "Configure IP address and netmask" \
		Gateway "Configure Gateway" \
		Exit "Exit to the shell" 2>"$F_MENU"

	menuitem=$(<"$F_MENU")

# make decsion 
	case $menuitem in
	Status) display_msg "$TITLE_STATUS" "$(<$F_STATUS_DISP)" 15 60;;
#	Manual) display_config_menu;;
	Configure) display_interface_select_menu config;;
	Gateway) display_gateway_config_menu;;
#	Gateway) display_interface_select_menu gateway;;
#	DHCP) display_dhcp_config_menu;;
	Exit) echo " "; clear;  break;
	esac
done
	
delete_temp

