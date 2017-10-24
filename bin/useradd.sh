#!/bin/bash

bakValidate () {
	backup_directory=~/backup
	
	if [[ -e $backup_directory ]]
		then
			logit "Directory $backup_directory exist"
		else
			logit "$backup_directory  does not exist"
			logit "Setting up $backup_directory"
			mkdir -pv $backup_directory >/dev/null 2>&1
			mkdir ~/log >/dev/null 2>&1; touch ~/log/useradd.sh.log  >/dev/null 2>&1
	fi
}

cliValidation () {
        cli_directory=~/client

        if [[ -e $cli_directory ]]
                then
                        logit "Directory $cli_directory exist"
                else
                        logit "$cli_directory  does not exist"
                        logit "Setting up $cli_directory"
                        mkdir -pv $cli_directory >/dev/null 2>&1
        fi
}

createBackup () {
	work_dir=/etc
	pam_file="common-password-pc"
	login_defs="login.defs"
	logit "Backing up $work_dir/$login_defs >>>>> $backup_directory ...."
	logit "Backing up $work_dir/pam.d/$pam_file >>>>> $backup_directory ...."
	sudo tar -cvpzf $backup_directory/backup-policy-$(date +"%m%d%Y%H%M").tar.gz $work_dir/$login_defs $work_dir/pam.d/$pam_file >/dev/null 2>&1
}

policyValidation () {
	createBackup
	logit "Checking up PASS_MAX_DAYS security policy"
	max_days=$(grep -v '^ *#' /etc/login.defs | grep PASS_MAX_DAYS | awk '{print $2}')
	if (( $max_days == 90 ))
	then
		logit "PASS_MAX_DAYS = $max_days TRUE"
	else
		logit "PASS_MAX_DAYS = $max_days FALSE"
		logit "Setting PASS_MAX_DAYS to 90 days"
		sudo sed -i -e "s/$max_days/90/g" /etc/login.defs
		#grep -v '^ *#' /etc/login.defs | grep PASS_MAX_DAYS
	fi
	logit "Checking up PAM Cracklib minimal length for password policy"
	if [[ -z "$(cat /etc/pam.d/common-password-pc | grep -w minlen)" ]]
	then
		logit "Cracklib policy = FALSE"
		logit "Setting up PAM cracklib password policy"
		sudo sed -i -e 's/pam_cracklib.so/pam_cracklib.so\ minlen=8/g' /etc/pam.d/common-password-pc
	else
		logit "PAM cracklib Policy = TRUE"
		logit "No PAM policy chages has been made"
	fi
}

sudoValidation () {

        logit "Checking up sudo privileges"
        if [[ -z "$(sudo cat /etc/sudoers | grep -w $user)" ]]
        then
                logit "Sudo privileges = FALSE"
                logit "Setting up sudo privileges"
		admin=`whoami`
		sudo cp /etc/sudoers /tmp/sudoers.bak
		sudo chmod 600 /tmp/sudoers.bak; sudo chown $admin:users /tmp/sudoers.bak 
                sudo echo "$user ALL=(ALL) NOPASSWD: ALL" >> /tmp/sudoers.bak
		sudo visudo -cf /tmp/sudoers.bak
			if [ $? -eq 0 ]; then
				sudo cp /tmp/sudoers.bak /etc/sudoers
				sudo chmod 440 /etc/sudoers
			else
				echo "Could not modify /etc/sudoers file. Please do this manually."
			fi
		sudo_display=`sudo cat /etc/sudoers | grep $user`
		echo "Sudo changes for $user: $sudo_display"
		logit "Sudo changes for $user: $sudo_display"
        else
                logit "Sudo privileges = TRUE"
		echo  "Sudo privileges = TRUE"
                logit "No sudo chages has been made"
		echo "No sudo chages has been made"
        fi
}

createUser () {
	read -p "Enter username : " user
	read -sp "Enter password : " password
	logit "Adding user $user"
	echo
	echo "Tesing password strength..."
	logit "Tesing password strength..."
	echo
	result="$(sudo cracklib-check <<<"$password")"
	okay="$(awk -F': ' '{ print $2}' <<<"$result")"
	if [[ "$okay" == "OK" ]]
	then
		echo "Password strength $okay"
		logit "Password strength OK"	
		echo "Adding a user account please wait..."
		sudo /usr/sbin/useradd -m -s /bin/bash $user
		echo "$user:$password" | sudo /usr/sbin/chpasswd
		echo -n "User $user has been created: "
		id $user
		logit "User $user has been created"
		logit "Generating ssh-key for $user"
		echo "Generating ssh-key for user $user"
		echo -e "\n" | sudo -u $user ssh-keygen -t rsa -b 2048 -f /home/$user/.ssh/id_rsa -P "">> ~/log/useradd.sh.log
		sudoValidation
		cliValidation
	else
		echo "Your password was rejected - $result"
		logit "Your password was rejected - $result"
        	echo "Try again."
		logit "Try again."
	fi
}

clientFile () {
		logit "Generating client file"
		cli_file=`hostname -f`.cli
		sshKey=`sudo cat /home/$user/.ssh/id_rsa.pub`
		echo "$user,$password,$sshKey" >> $cli_directory/$cli_file
}

logit () {
        logfile=~/log/useradd.sh.log
        logtime=$(date "+%F %T")
        echo "[$logtime] $1 "  >> $logfile 2>&1
}

bakValidate
policyValidation
createUser
clientFile
