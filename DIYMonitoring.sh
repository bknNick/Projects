#!/bin/bash

#############################################################################################################################################################
##---------------------------------------------------------------------DIY MONITORING----------------------------------------------------------------------##
#############################################################################################################################################################

#############################################################################################################################################################
## Monitoring script, does a check in real time on most monitored resources and provides feedback related to them. This is meant to be run as root until I ##
## find a work-around for sudo (as soon as I stop being lazy about it at least).                                                                           ##
##                                                                                                                                                         ##
## Obviously done by Nick D., as these lazy asses wouldn't be bothered with such things -_- (talking to you Steve & George).                               ##
##                                                                                                                                                         ##
## If no output is returned, then all is working as intended.                                                                                              ##
#############################################################################################################################################################

FSmonitoring(){
####### DISC usage monitoring - checks the filesystems, and if any usage issues are detected, provides a list with the largest files.

        for FSusage in $(df -h | awk '{print $5}' | grep -vi "use" | cut -d "%" -f 1); do
                if (( $FSusage >= $DiscUsageThreshold )); then
                        printf "\nFS issue detected in the following FS', please review!\n"
                        echo $(df -h | grep "$FSusage")
                        printf "\nThe largest files can be found below:\n"
                        printf "\n"
                        for DiscUsageFile in $(find / -type f -size +1000000c -exec du -m {} \; 2>/dev/null | sort -n -k 1 | tail -20 | awk {'print ($2)'});
                                do ls -l --block-size=M -a $DiscUsageFile
                        done
                        printf "\n"
                fi
        done

######## INODE usage monitoring - same as the above, but prints out a list with the directories using the most inodes.
        for iusage in $(df -i | awk '{print $5}' | grep -vi "use" | cut -d "%" -f 1); do
                if (( $iusage >= $InodeUsageThreshold )); then
                        printf "\nInode issue detected in the following FS', please review!\n"
                        echo "$(df -i | grep "$iusage"%)"
                        printf "\nDirectories with the most inodes on the system can be found below:\n"
                        find / -xdev -printf '%h\n' | sort | uniq -c | sort -k 1 -n | tail -20
                        printf "\n"
                fi
        done

####### Read only FS check
        local RO=$(grep "ro," /proc/mounts| grep -vi tmpfs)
        if [[ $RO ]]; then
                printf "\nRead only filesystem detected!\n"
                echo "$RO"
                printf "\n"
        fi
}


MEMmonitoring(){
####### Free MEMORY monitoring - checks the memory usage, if above threshold, provides a list with the top memory consuming processes.

        local FreeMem=$(free -m | grep -i "mem" | awk '{print ($4 * 100 / $2)}' | cut -d "." -f 1)
        if (( $FreeMem <= $FreeMemThreshold )); then
                printf "\n"
                echo "Memory issue detected! Free memory is only $FreeMem%!"
                printf "\n"
                printf "The highest memory consuming processes can be found below:\n"
                ps -eo pid,ppid,stat,vsz,rss,comm --sort=rss | tail -20
                printf "\n"
        fi
}


SvcsMonitoring(){
####### Services monitoring - checks if services are running, if not tries to start them.

#HTTPD CHECK:
        local ApacheDown=$(/bin/systemctl status httpd | grep -i "Active: inactive (dead)")
        local ApacheStart="/bin/systemctl start httpd"
        local ApacheStatus="/bin/systemctl status httpd"
        if [[ $ApacheDown ]]; then
                printf "\nHTTPD service was stopped. Trying to start it...\n"
                $ApacheStart > /dev/null
                wait
                local ApacheDown=$(/bin/systemctl status httpd | grep -i "Active: inactive (dead)")
                if [[ $ApacheDown ]]; then
                        printf "\nHTTPD issue detected. Please review!\n"
                        $ApacheStatus
                elif [[ ! $ApacheDown ]]; then
                        printf "HTTPD successfully started.\n"
                        printf "\n"
                fi
        fi

#MySQL Check:
        local MySQLDown=$(/bin/systemctl status mysqld | grep -i "Active: inactive (dead)")
        local MySQLStart="/bin/systemctl start mysqld"
        local MySQLStatus="/bin/systemctl status mysqld"
        if [[ $MySQLDown ]]; then
                printf "MySQL service was stopped. Trying to start it...\n"
                $MySQLStart > /dev/null
                wait
                local MySQLDown=$(/bin/systemctl status mysqld | grep -i "Active: inactive (dead)")
                if [[ $MySQLDown ]]; then
                        printf "\nMySQL issue detected. Please review!\n"
                        $MySQLStatus
                elif [[ ! $MySQLDown ]]; then
                        printf "MySQL successfully started.\n"
                        printf "\n"
                fi
        fi

}


#SystemCheck(){ // need to add this

########################################################################CONFIGURATION HERE###############################################################

##THRESHOLDS IN PERCENTAGES
DiscUsageThreshold=70
InodeUsageThreshold=70
FreeMemThreshold=10


##ENABLE/DISABLE MONITORING BY COMMENTING OUT SPECIFIC FUNCTIONS HERE:
FSmonitoring
MEMmonitoring
SvcsMonitoring
