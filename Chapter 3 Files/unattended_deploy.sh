#!/bin/bash

  # Passwords are arbitary. Hardcoded until I can figure out how to make /dev/urandom work in GitHub Actions.
function generatepasswords_unattended() {

  elastic_user_pass=dvXFkH9CnFuW3CcvYYEiYwB0ziOt08DE
  kibana_system_pass=HIPhq05lfssUFkkv1LoElDMwqSZyg4nH
  logstash_system_pass=17C5AqhMrdugqKwCRrsTZBcqRAweFfr9
  logstash_writer=UFDYu0wQPe0mF3TeuDqUW2hPp6XjQylp
  update_user_pass=igruJgENgN62PNphKewEa3EKIPsjFcV7
  kibanakey=RS3Z7W7rzjXAjhfclfgebR4PwUXxSPuHht8U0rAzak

  echo -e "\e[32m[X]\e[0m Updating logstash configuration with logstash writer"
  cp /opt/lme/Chapter\ 3\ Files/logstash.conf /opt/lme/Chapter\ 3\ Files/logstash.edited.conf
  sed -i "s/insertlogstashwriterpasswordhere/$logstash_writer/g" /opt/lme/Chapter\ 3\ Files/logstash.edited.conf
}

  # We can remove this function when this function is fixed on deploy.sh

function data_retention_unattended() {
  #show ext4 disk
  DF_OUTPUT="$(df -h -l -t ext4 --output=source,size /var/lib/docker)"
  #pull dev name
  DISK_DEV="$(echo "$DF_OUTPUT" | grep -Po '[0-9]+G')"
  #pull dev size
  DISK_SIZE_ROUND="${DISK_DEV/G/}"
  #lets do math to get 75% (%80 is low watermark for ES but as curator uses this we want to delete data *before* the disk gets full)
  DISK_80=$((DISK_SIZE_ROUND * 80 / 100))
  echo -e "\e[32m[X]\e[0m We think your main disk is $DISK_DEV"
  if [ "$DISK_80" -lt 30 ]; then
    echo -e "\e[31m[!]\e[0m LME Requires 128GB of space usable for log retention - exiting"
    exit 1
  elif [ "$DISK_80" -ge 30 ] && [ "$DISK_80" -le 179 ]; then
    RETENTION="30"
  elif [ "$DISK_80" -ge 180 ] && [ "$DISK_80" -le 359 ]; then
    RETENTION="90"
  elif [ "$DISK_80" -ge 360 ] && [ "$DISK_80" -le 539 ]; then
    RETENTION="180"
  elif [ "$DISK_80" -ge 540 ] && [ "$DISK_80" -le 719 ]; then
    RETENTION="270"
  elif [ "$DISK_80" -ge 720 ]; then
    RETENTION="365"
  else
    echo -e "\e[31m[!]\e[0m Unable to determine retention policy - exiting"
    exit 1
  fi
  echo -e "\e[32m[X]\e[0m We are assigning $RETENTION days as your retention period for log storage"
  curl --cacert certs/root-ca.crt --user "elastic:$elastic_user_pass" -X PUT "https://127.0.0.1:9200/_ilm/policy/lme_ilm_policy" -H 'Content-Type: application/json' -d'
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_age": "30d",
            "max_primary_shard_size": "50gb"
          }
        }
      },
      "warm": {
        "min_age": "2d",
        "actions": {
          "shrink": {
            "number_of_shards": 1
          }
        }
      },
      "delete": {
        "min_age": "'$RETENTION'd",
        "actions": {
          "delete": {
            "delete_searchable_snapshot": true
          }
        }
      }
    },
    "_meta": {
      "description": "LME ILM policy using the hot and warm phases with a retention of '$RETENTION' days"
    }
  }
}
'
}

function unattended_install() {
  echo -e "\e[32m[X]\e[0m Updating OS software"
  apt update && apt upgrade -y
  echo -e "\e[32m[X]\e[0m Installing prerequisites"
  apt install curl zip net-tools -y -q
  #enable auto updates if ubuntu
  auto_os_updates
  #move configs
  cp docker-compose-stack.yml docker-compose-stack-live.yml
  #find the IP winlogbeat will use to communicate with the logstash box (on elk)
  #get interface name of default route
  DEFAULT_IF="$(route | grep '^default' | grep -o '[^ ]*$')"
  #get ip of the interface
  EXT_IP="$(/sbin/ifconfig "$DEFAULT_IF" | awk -F ' *|:' '/inet /{print $3}')"

  # Set values for unattended install
  logstaship=${LOGSTASH_IP:-$EXT_IP}
  logstashcn=${LOGSTASH_CN:-"ls1.lme.local"}
  selfsignedyn=${SELFSIGNED_YN:-"y"}
  skipdinstall=${SKIP_DINSTALL:-"n"}

  if [ "$selfsignedyn" == "y" ]; then
    #make certs
    generateCA
    generatelogstashcert
    generateclientcert
    generateelasticcert
    generatekibanacert
  elif [ "$selfsignedyn" == "n" ]; then
    echo "Please make sure you have the following certificates named correctly"
    echo "./certs/root-ca.crt"
    echo "./certs/elasticsearch.key"
    echo "./certs/elasticsearch.crt"
    echo "./certs/logstash.crt"
    echo "./certs/logstash.key"
    echo "./certs/kibana.crt"
    echo "./certs/kibana.key"
    echo -e "\e[32m[X]\e[0m Checking for root-ca.crt"
    if [ ! -f ./certs/root-ca.crt ]; then
      echo -e "\e[31m[!]\e[0m File not found!"
      exit 1
    fi
    echo -e "\e[32m[X]\e[0m Checking for elasticsearch.key"
    if [ ! -f ./certs/elasticsearch.key ]; then
      echo -e "\e[31m[!]\e[0m File not found!"
      exit 1
    fi
    echo -e "\e[32m[X]\e[0m Checking for elasticsearch.crt"
    if [ ! -f ./certs/elasticsearch.crt ]; then
      echo -e "\e[31m[!]\e[0m File not found!"
      exit 1
    fi
    echo -e "\e[32m[X]\e[0m Checking for logstash.crt"
    if [ ! -f ./certs/logstash.crt ]; then
      echo -e "\e[31m[!]\e[0m File not found!"
      exit 1
    fi
    echo -e "\e[32m[X]\e[0m Checking for logstash.key"
    if [ ! -f ./certs/logstash.key ]; then
      echo -e "\e[31m[!]\e[0m File not found!"
      exit 1
    fi
    echo -e "\e[32m[X]\e[0m Checking for kibana.crt"
    if [ ! -f ./certs/kibana.crt ]; then
      echo -e "\e[31m[!]\e[0m File not found!"
      exit 1
    fi
    echo -e "\e[32m[X]\e[0m Checking for kibana.key"
    if [ ! -f ./certs/kibana.key ]; then
      echo -e "\e[31m[!]\e[0m File not found!"
      exit 1
    fi
  else
    echo "Not a valid option"
  fi

  if [ "$skipdinstall" == "n" ]; then
    installdocker
  fi
  initdockerswarm
  populatecerts
  generatepasswords_unattended
  populatelogstashconfig
  configuredocker
  pulllme
  deploylme
  setpasswords
  configelasticsearch
  zipfiles

  #pipelines
  pipelineupdate

  #ILM
  data_retention_unattended

  #index mapping
  indexmappingupdate

  #bootstrap
  bootstrapindex

  #create config file
  writeconfig

  #dashboard upload
  uploaddashboards

  #prompt user to enable auto update
  #Deprecated
  #promptupdate

  #fix readability:
  fixreadability
  
  echo ""
  echo "##################################################################################"
  echo "## Kibana/Elasticsearch Credentials are (these will not be accessible again!)"
  echo "##"
  echo "## Web Interface login:"
  echo "## elastic:$elastic_user_pass"
  echo "##"
  echo "## System Credentials"
  echo "## kibana:$kibana_system_pass"
  echo "## logstash_system:$logstash_system_pass"
  echo "## logstash_writer:$logstash_writer"
  echo "## dashboard_update:$update_user_pass"
  echo "##################################################################################"
  echo ""
}

############
#START HERE#
############
export CERT_STRING='/C=US/ST=DC/L=Washington/O=CISA'
#Check the script has the correct permissions to run
if [ "$(id -u)" -ne 0 ]; then
  echo -e "\e[31m[!]\e[0m This script must be run with root privileges"
  exit 1
fi
#Check the install location
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
if [[ "$DIR" != "/opt/lme/Chapter 3 Files" ]]; then
  echo -e "\e[31m[!]\e[0m The deploy script is not currently within the correct path, please ensure that LME is located in /opt/lme for installation"
  exit 1
fi
#Change current working directory so relative filepaths work
cd "$DIR" || exit

# Determine the directory of deploy.sh
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source deploy.sh from the same directory
source "$DIR/deploy.sh"

# Now execute the unattended_install function or any other logic you need
unattended_install