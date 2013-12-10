#!/usr/local/bin/bash

# Define TRUE and FALSE
TRUE=0
FALSE=1

# Temp files
F_MENU=./.menu.tmp
F_ERROR=./error.log
F_CHK_CFG=./.chk.config.tmp
F_STATUS=./.status.tmp

# Title and message
BACKTITLE="Bridge Configuration Tool"
TITLE_MAIN="[ M A I N - M E N U ]"
TITLE_STATUS="[ S T A T U S ]"
TITLE_IF="[ I N T E R F A C E - S E L E C T ]"
TITLE_ADD_RM="[ A D D / R E M O V E]"
MENU_MSG="You can use the UP/DOWN arrow keys, the first \
letter of the choice as a hot key, or the \
number keys 1-9 to choose an option.\\n\
Choose the TASK"
CHKLS_MSG="Select for add and unselect for remove interface from bridge\\n\
Select the interface:"

# Global variable
CHK_STR=""
CHK_STR_ARRAY=("")
CHK_IF_ARRAY=("")

# Show configuration result
function show_config_result(){
	if [ $? -eq 1 ]; then
		# Should not happened
		display_msg "Error" "$(<$F_ERROR)" 10 50
		return $FALSE;
	else
		display_msg "Configuration Result" "$1" 5 30
		return $TRUE;
	fi
}

# Create or destroy a bridge
function create_bridge(){
	ifconfig bridge create >& $F_ERROR
	scan_interface
	if [ $? -eq 0 ]; then
		show_config_result "Create `cat $F_ERROR` success!"
		return $TRUE;
	else
		show_config_result
		return $FALSE;
	fi	
}

# Destroy or destroy a bridge
function destroy_bridge(){
	ifconfig $1 destroy >& $F_ERROR
	if [ $? -eq 0 ]; then
		show_config_result "Destroy $1 success!"
		return $TRUE;
	else
		show_config_result "`cat $F_ERROR`"
		return $FALSE;
	fi	
}

function scan_interface(){
	IF=`ifconfig | grep flags | grep -v bridge | grep -v lo | \
		grep -v member | awk -F: '{print $1}'`
	IF_ARRAY=(`ifconfig | grep flags | grep -v bridge | \
				grep -v lo | grep -v member| awk -F: '{print $1}'`)
	IF_COUNT=${#IF_ARRAY[@]}
	B_IF=`ifconfig  | grep bridge | awk -F: '{print $1}'`
	B_IF_ARRAY=(`ifconfig | grep bridge | awk -F: '{print $1}'`)
	B_IF_COUNT=${#B_IF_ARRAY[@]}
}

# Prepare checklist
function prepare_checklist(){
	local loop=0
	local member_flag=0

	for iface in $IF; do
		loop=$(($loop+1))
		for member in `ifconfig "$interface" | grep member | awk '{print $2}'`; do
			if [ "$iface" = "$member" ]; then
				member_flag=1
				break
			fi
		done
		if [ $member_flag -eq 0 ]; then
			CHK_STR="$CHK_STR `echo $loop $iface off `"
		else
			CHK_STR="$CHK_STR `echo $loop $iface on `"
		fi
		member_flag=0
	done

	CHK_STR_ARRAY=($CHK_STR)
}

# Update checklist
function update_checklist(){
	local index
	local check
	local loop
	local add_flag

#	`echo "${CHK_STR[@]}" | sed -e 's/on/off/g'`
	echo ${CHK_STR_ARRAY[@]};read
	# Add interface to bridge
	for ((i=0; i<$IF_COUNT; i++)); do
		echo "i: $i"
		add_flag=0
		for check in `echo $(<$F_MENU) | sed -e 's/"//g'`; do
			echo "check: $check"
			if [ "$check" = "$(($i+1))" ]; then
				add_flag=1
				# Skip if this interface already a member of bridge 
				if [ "${CHK_STR_ARRAY[$(($i*3+2))]}" = "off" ]; then
					CHK_STR_ARRAY[$(($i*3+2))]="on"
					ifconfig $interface addm ${CHK_STR_ARRAY[$(($i*3+1))]} >& $F_ERROR
				fi
				break
			fi

			if [ $add_flag -eq 0 ]; then
				# Skip if this interface is not a member of bridge
				if [ "${CHK_STR_ARRAY[$(($i*3+2))]}" = "on" ]; then
					CHK_STR_ARRAY[$(($i*3+2))]="off"
					ifconfig $interface deletem ${CHK_STR_ARRAY[$(($i*3+1))]} >& $F_ERROR
				fi
			fi
		done
	done

#	echo ${CHK_STR_ARRAY[@]};read
	CHK_STR=${CHK_STR_ARRAY[@]}
#	echo $CHK_STR; read
}

function show_status(){
	if [ -z "$B_IF" ]; then
		display_msg "Error" "No bridge interface!" 15 50
		return $FALSE
	fi

	printf "BridgeName              Member\\\n" > $F_STATUS
	for iface in $B_IF; do
		local flag=0
		printf "$iface" >> $F_STATUS
		for member in `ifconfig $iface | grep member | awk '{print $2}'`; do
			if [ $flag -eq 0 ]; then
				printf "%$((24-${#B_IF_ARRAY[0]}))s$member\\\n" >> $F_STATUS
				flag=1
			else	
				printf "%24s$member\\\n" >> $F_STATUS
			fi
		done
		printf "\\\n" >> $F_STATUS
	done

	display_msg "$TITLE_STATUS" "$(<$F_STATUS)" 15 60
	return $TRUE
}

# Delete temp file
function delete_temp(){
	rm -rf .*.tmp
}

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
#                     CHECK list                      #
#######################################################
# Display checklist
function display_interface_check_list(){
	if [ -z "$IF" ]; then
		display_msg "Error" "No interface can be add to bridge." 10 50
		return $FALSE;
	fi

	prepare_checklist

	while true; do
		dialog --backtitle "$BACKTITLE" \
			--title "$TITLE_ADD_RM" \
			--checklist "$CHKLS_MSG" 15 50 $IF_COUNT \
			$CHK_STR 2> "$F_MENU"
		
		update_checklist; break
	done
}

#######################################################
#                        MENU                         #
#######################################################
# Display menu
function display_bridge_select_menu(){
	scan_interface

	if [ -z "$B_IF" ]; then
		display_msg "Error" "No bridge interface exist,\nplease create first." 10 50
		retrun $FALSE;
	else	

		local loop=0
		local str=`for iface in $B_IF; do loop=$(($loop+1)); echo $iface $loop; done`

		while true; do
			dialog --clear --backtitle "$BACKTITLE" \
				--title "$TITLE_IF" \
				--menu "$MENU_MSG" 15 50 $(($B_IF_COUNT+1)) \
				$str \
				Exit "Exit to main menu" 2>"$F_MENU"

			menuitem=$(<"$F_MENU")

			# make decsion 
			case $menuitem in
			Exit) break ;;
			*)  if [ "$1" = "addrm" ]; then
					for iface in $B_IF; do
						if [ "$iface" = "$menuitem" ]; then
							interface=$iface
						fi
					done
					display_interface_check_list
				fi

				if [ "$1" = "destroy" ]; then
					for iface in $B_IF; do
						if [ "$iface" = "$menuitem" ]; then
							interface=$iface
						fi
					done
					destroy_bridge $menuitem
				fi
				break 
			esac
		done

		return $TRUE;
	fi
}

function display_config_menu(){
	while true; do
		dialog --clear --backtitle "$BACKTITLE" \
			--title "$TITLE_IF" \
			--menu "$MENU_MSG" 15 65 4 \
			Create "Create Bridge Interface" \
			"Add / Remove" "Add or Remove Member from Bridge Interface" \
			Destroy "Destroy Bridge Interface" \
			Exit "Exit to main menu" 2>"$F_MENU"

		menuitem=$(<"$F_MENU")

		# make decsion 
		case $menuitem in
		Create) create_bridge ;;
		"Add / Remove") display_bridge_select_menu addrm ;;
		Destroy) display_bridge_select_menu destroy ;;
		Exit) break 
		esac
	done

	return $TRUE;
}

# main
delete_temp
scan_interface
#status2file

# set infinite loop
while true; do
# display main menu
	dialog --clear  --help-button --backtitle "$BACKTITLE" \
		--title "$TITLE_MAIN" \
		--menu "$MENU_MSG" 15 40 3 \
		Status "Display status" \
		Configure "Bridge Configuration" \
		Exit "Exit to the shell" 2>"$F_MENU"

	menuitem=$(<"$F_MENU")

# make decsion 
	case $menuitem in
	Status) show_status;;
	Configure) display_config_menu;;
	Exit) echo " "; clear;  break
	esac
done
	
delete_temp

