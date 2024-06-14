#!/bin/bash
# set -x
#####################################################################################
# Name          satellite_register_client.sh
# Description   Register Linux server in Red Hat Satellite & Insights
# Arguments     ---
# Author        Erwin Van der Donck
# Version       1.0     14/07/2023      Initial script
#####################################################################################

source /etc/profile.d/pv_functions.sh

###################################
# FUNCTION fullpath
#    Returns full path of file name
###################################
function fullpath
{
   local _FILENAME=$1

   ### Argument is directory
   if [[ -d $_FILENAME ]]
   then
      pwd
   ### Argument is file
   else
      cd $(dirname $_FILENAME) > /dev/null
      pwd
      cd - > /dev/null
   fi
}

###################################
# FUNCTION display_logfile
#    Display log file and restore
#    redirections
###################################
function display_logfile
{
   ### Restore redirect output
   exec 2>&-
   exec 1>&-

   ### Ouput log file
   cat $LOGFILE
}

###################################
# FUNCTION print_header
#    Print header
###################################
function print_header
{
   HEADER="START $SCRIPT_PATH $DATE_STRING"
   mecho ${HEADER_FOOTER_LINE:0:${#HEADER}}
   mecho $HEADER
   mecho ${HEADER_FOOTER_LINE:0:${#HEADER}}
   mecho
}

###################################
# FUNCTION print_footer
#    Print footer
###################################
function print_footer
{
   DATE_TIMESTAMP=$(echo $(date +%d%m%Y%H%M%S%N) | awk '{printf "%04d%02d%02d%09d",substr($0,5,4),substr($0,3,2),substr($0,1,2),substr($0,9,9);}')
   DATE_STRING="${DATE_TIMESTAMP:6:2}/${DATE_TIMESTAMP:4:2}/${DATE_TIMESTAMP:0:4} ${DATE_TIMESTAMP:8:2}:${DATE_TIMESTAMP:10:2}:${DATE_TIMESTAMP:12:2}.${DATE_TIMESTAMP:14:3}"
   mecho
   FOOTER="END $SCRIPT_PATH $DATE_STRING"
   mecho ${HEADER_FOOTER_LINE:0:${#FOOTER}}
   mecho $FOOTER
   mecho ${HEADER_FOOTER_LINE:0:${#FOOTER}}
}

###################################
# FUNCTION script_exit
#    Display footer, display log
#    file and generate exit code
###################################
function script_exit
{
   local _RC=$1

   print_footer
   #display_logfile

   exit ${_RC}
}

###################################
# FUNCTION mecho
#    Display message line
#    including all arguments
###################################
function mecho
{
   echo -n "$1"
   if [[ $2 != '' ]]; then
      echo -n ": $2"
   fi
   echo
}

#############
### VARIABLES
#############
SCRIPT_PATH=$0
SCRIPT_NAME=${SCRIPT_PATH##*/}
ROOT_DIR=$(fullpath ${SCRIPT_PATH})
LOGS_DIR=${ROOT_DIR}/logs
HEADER_FOOTER_LINE='============================================================================================================'
SATELLITE_ORGANIZATION='P_V'
SATELLITE_SERVER='pvx9sat1n1.ux.pv.be'

#########
### BEGIN
#########
DATE_TIMESTAMP=$(echo $(date +%d%m%Y%H%M%S%N) | awk '{printf "%04d%02d%02d%09d",substr($0,5,4),substr($0,3,2),substr($0,1,2),substr($0,9,9);}')
DATE_STRING="${DATE_TIMESTAMP:6:2}/${DATE_TIMESTAMP:4:2}/${DATE_TIMESTAMP:0:4} ${DATE_TIMESTAMP:8:2}:${DATE_TIMESTAMP:10:2}:${DATE_TIMESTAMP:12:2}.${DATE_TIMESTAMP:14:3}"

### Redirect stdout/stderr to log file
LOGFILE=${LOGS_DIR}/${SCRIPT_NAME}.log.${DATE_TIMESTAMP}
exec &> >(tee -a "$LOGFILE")

#####################################
### Print script header
#####################################
print_header

mecho 'INFO' 'Registration of Linux Server to Satellite Server'
mecho 'INFO' '================================================'
mecho 'INFO' 

### Prevent Red Hat Satellite servers being registered to Satellite servers
HOSTNAME_UPPERCASE=$(hostname | tr '[:lower:]' '[:upper:]')
mecho 'INFO' '================================================'
mecho 'INFO' ${HOSTNAME_UPPERCASE}
mecho 'INFO' '================================================'
echo ${HOSTNAME_UPPERCASE} | egrep -q 'PVX.*SAT' 
if [ $? -eq 0 ]; then
   echo "Satellite servers can't be registered to satellite servers! Will be skipped."
   exit
fi

### Determine Environment
ENVIRONMENT_NUMBER=${HOSTNAME_UPPERCASE:3:1}
if [ ${ENVIRONMENT_NUMBER} -eq 0 ]; then
   ENVIRONMENT='cab'
elif [ ${ENVIRONMENT_NUMBER} -eq 1 ]; then
   ENVIRONMENT='byld'
elif [ ${ENVIRONMENT_NUMBER} -eq 2 ]; then
   ENVIRONMENT='test'
elif [ ${ENVIRONMENT_NUMBER} -eq 6 ]; then
   ENVIRONMENT='form'
elif [ ${ENVIRONMENT_NUMBER} -eq 7 ]; then
   ENVIRONMENT='accp'
elif [ ${ENVIRONMENT_NUMBER} -eq 8 ]; then
   ENVIRONMENT='ppro'
elif [ ${ENVIRONMENT_NUMBER} -eq 9 ]; then
   ENVIRONMENT='prod'
fi
mecho 'INFO' "Environment is $ENVIRONMENT"

### Determine Red Hat Linux Server release
OS_RELEASE=$(cat /etc/system-release)
echo ${OS_RELEASE} | grep -q 'Red Hat Enterprise Linux Server release 6'
if [ $? -eq 0 ]; then
   RHEL_RELEASE='rhel6'
else 
   echo ${OS_RELEASE} | grep -q 'Red Hat Enterprise Linux Server release 7'
   if [ $? -eq 0 ]; then
      RHEL_RELEASE='rhel7'
   else 
      echo ${OS_RELEASE} | grep -q 'Red Hat Enterprise Linux release 8'
      if [ $? -eq 0 ]; then
         RHEL_RELEASE='rhel8'
      fi
   fi
fi
mecho 'INFO' "Red Hat Linux Server release is ${RHEL_RELEASE}"
echo

#mecho 'INFO' 'Unregister Red Hat Insights client'
#mecho 'INFO' '=================================='
#[ -f /usr/bin/insights-client ] && insights-client --unregister
#mecho

mecho 'INFO' 'Disable Amazon repositories'
mecho 'INFO' '==========================='
REPO='/etc/yum.repos.d/redhat-rhui-beta.repo'
[[ -f ${REPO} ]] && mv ${REPO} ${REPO}.disabled
REPO='/etc/yum.repos.d/redhat-rhui-client-config.repo'
[[ -f ${REPO} ]] && mv ${REPO} ${REPO}.disabled
REPO='/etc/yum.repos.d/redhat-rhui-eus.repo'
[[ -f ${REPO} ]] && mv ${REPO} ${REPO}.disabled
REPO='/etc/yum.repos.d/redhat-rhui.repo'
[[ -f ${REPO} ]] && mv ${REPO} ${REPO}.disabled
mecho

mecho 'INFO' 'Enable repository management in Subscription Manager'
mecho 'INFO' '===================================================='
RHSM_CONFIG='/etc/rhsm/rhsm.conf'
egrep -q 'manage_repos.*=.*1' ${RHSM_CONFIG}
if [ $? -ne 0 ]; then
   mecho 'Repository management is disabled in Subscription Manager'
   saveversion ${RHSM_CONFIG}
   sed -i 's/manage_repos.*=.*/manage_repos = 1/' ${RHSM_CONFIG}
   mecho 'Repository management is enabled now in Subscription Manager'
else
   mecho 'Repository management is already enabled in Subscription Manager'
fi
mecho

mecho 'INFO' 'Unregister Linux server with Subscription Manager'
mecho 'INFO' '================================================='
subscription-manager unregister
subscription-manager clean
mecho

#mecho 'INFO' 'Uninstall Katello Agent (optional)'
#mecho 'INFO' '=================================='
#yum remove -y katello-agent
#mecho

mecho 'INFO' 'Register Linux server with Subscription Manager'
mecho 'INFO' '==============================================='
yum install -y --nogpgcheck http://${SATELLITE_SERVER}/pub/katello-ca-consumer-latest.noarch.rpm
SATELLITE_ACTIVATION_KEY="${ENVIRONMENT}-${RHEL_RELEASE}"
subscription-manager register --name=$(hostname -s) --org="${SATELLITE_ORGANIZATION=}" --activationkey="${SATELLITE_ACTIVATION_KEY}" 
subscription-manager refresh
yum clean all
[[ -d /var/cache/dnf ]] && rm -rf /var/cache/dnf/*
[[ -d /var/cache/yum ]] && rm -rf /var/cache/yum/*
mecho

mecho 'INFO' 'Installation of Katello host tools package'
mecho 'INFO' '=========================================='
yum install -y katello-host-tools.noarch
mecho

#mecho 'INFO' 'Register Red Hat Insights client'
#mecho 'INFO' '================================'
#yum install -y insights-client.noarch
#insights-client --register 
### In case of problem solving
#insights-client --checkin
#insights-client --test-connection
#mecho


mecho 'INFO' 'Configure Foreman public key'
mecho 'INFO' '============================'
if [ $(grep -c "foreman-proxy" /root/.ssh/authorized_keys) -eq 0 ]
then
    mecho 'INFO' "Foreman public key not found, adding..."
    curl -s https://${SATELLITE_SERVER}:9090/ssh/pubkey >> ~/.ssh/authorized_keys
    mecho 'INFO' "Added!"
else
    mecho 'INFO' "Foreman public key is already present!"
fi
echo

script_exit 0

#######
### END
#######

