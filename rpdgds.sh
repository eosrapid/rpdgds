#!/bin/bash
BASH_FILE_ME=${BASH_SOURCE[0]}
EOS_SYSTEM_TYPE="ubuntu-16.04_amd64"
EOS_DEFAULT_VERSION="2.0.5"

MICRO_SYSTEM_TYPE="linux64"
MICRO_DEFAULT_VERSION="2.0.0"

EXISTING_AUTHORIZED_KEYS_FILE="/home/ubuntu/.ssh/authorized_keys"

CHRONY_SERVER="server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4"



# start files inline
EOS_GENESIS_JSON=$(cat <<EOF
{
  "initial_timestamp": "2018-06-08T08:08:08.888",
  "initial_key": "EOS7EarnUhcyYqmdnPon8rm7mBCTnBoot6o7fE2WzjvEX2TdggbL3",
  "initial_configuration": {
    "max_block_net_usage": 1048576,
    "target_block_net_usage_pct": 1000,
    "max_transaction_net_usage": 524288,
    "base_per_transaction_net_usage": 12,
    "net_usage_leeway": 500,
    "context_free_discount_net_usage_num": 20,
    "context_free_discount_net_usage_den": 100,
    "max_block_cpu_usage": 200000,
    "target_block_cpu_usage_pct": 1000,
    "max_transaction_cpu_usage": 150000,
    "min_transaction_cpu_usage": 100,
    "max_transaction_lifetime": 3600,
    "deferred_trx_expiration_window": 600,
    "max_transaction_delay": 3888000,
    "max_inline_action_size": 4096,
    "max_inline_action_depth": 4,
    "max_authority_depth": 6
  }
}
EOF
)


EOS_LOGGING_JSON=$(cat <<EOF
{
    "includes": [],
    "appenders": [{
        "name": "consoleout",
        "type": "console",
        "args": {
            "stream": "std_out",
            "level_colors": [{
                "level": "debug",
                "color": "green"
            },{
                "level": "warn",
                "color": "brown"
            },{
                "level": "error",
                "color": "red"
            }]
        },
        "enabled": true
    }],
    "loggers": [{
        "name": "default",
        "level": "info",
        "enabled": true,
        "additivity": false,
        "appenders": [
            "consoleout"
        ]
    }]
}
EOF
)




# end files inline



function githubLatestTag {
    finalUrl=$(curl "https://github.com/$1/releases/latest" -s -L -I -o /dev/null -w '%{url_effective}')
    echo "${finalUrl##*v}"
}

installmicro() {
  TAG=${1:-$MICRO_DEFAULT_VERSION}
  platform=$MICRO_SYSTEM_TYPE
  echo "Downloading https://github.com/zyedidia/micro/releases/download/v$TAG/micro-$TAG-$platform.tar.gz"
  curl -L "https://github.com/zyedidia/micro/releases/download/v$TAG/micro-$TAG-$platform.tar.gz" > micro.tar.gz
  tar -xvzf micro.tar.gz "micro-$TAG/micro"
  sudo mv "micro-$TAG/micro" /usr/local/bin/micro
  rm micro.tar.gz
  rm -rf "micro-$TAG"
}

setupsshfix() {
  FILENAME=$1
  if sudo grep -xq "PasswordAuthentication no" "$FILENAME"
  then
      # code if found
      echo "PasswordAuthentication already disabled"
  else
      # code if not found
      echo -e "\n\nPasswordAuthentication no\n" | sudo tee -a $FILENAME
  fi

  if sudo grep -xq "ChallengeResponseAuthentication no" "$FILENAME"
  then
      # code if found
      echo "ChallengeResponseAuthentication already disabled"
  else
      # code if not found
      echo -e "\n\nChallengeResponseAuthentication no\n" | sudo tee -a $FILENAME
  fi
}
addsudonopw() {
  USERNAME_MOD=$1
  STR_CFG="${USERNAME_MOD} ALL=(ALL) NOPASSWD: ALL"

  if sudo grep -xq "$STR_CFG" "/etc/sudoers"
  then
      # code if found
      echo "sudo login already enabled"
  else
      # code if not found
      echo "$STR_CFG" | sudo tee -a /etc/sudoers
  fi
}

setupsshuser() {
  NEW_USER_NAME=$1
  NEW_USER_HOME="/home/${NEW_USER_NAME}"
  

  sudo useradd -m -d "$NEW_USER_HOME" -s /bin/bash $NEW_USER_NAME
  sudo mkdir -p "${NEW_USER_HOME}/.ssh"
  sudo cp $EXISTING_AUTHORIZED_KEYS_FILE "${NEW_USER_HOME}/.ssh"

  sudo chown -R $NEW_USER_NAME:$NEW_USER_NAME "${NEW_USER_HOME}/.ssh"
  sudo chmod 700 "${NEW_USER_HOME}/.ssh"
  sudo chmod 600 "${NEW_USER_HOME}/.ssh/authorized_keys"
  sudo usermod -aG sudo $NEW_USER_NAME
  setupsshfix /etc/ssh/sshd_config
  addsudonopw $NEW_USER_NAME
  sudo systemctl restart ssh
}


setupdeps() {
  sudo apt-get update
  sudo apt-get -y upgrade
  sudo apt-get update
  sudo apt-get install -y nano git curl wget chrony jq sysstat unzip zip coreutils gzip

  if sudo grep -xq "$CHRONY_SERVER" /etc/chrony/chrony.conf
  then
      echo "aws chrony server already enabled"
  else
      sudo sed -i "1s/^/$CHRONY_SERVER\n/" /etc/chrony/chrony.conf
      sudo /etc/init.d/chrony restart
  fi

  installmicro 2.0.0
}
installeosnormal() {
  EOS_VERSION=${1:-$EOS_DEFAULT_VERSION}
  DEB_URL="https://github.com/EOSIO/eos/releases/download/v${EOS_VERSION}/eosio_${EOS_VERSION}-1-${EOS_SYSTEM_TYPE}.deb"
  curl -L -o "./eosio_${EOS_VERSION}-1-${EOS_SYSTEM_TYPE}.deb" $DEB_URL
  sudo apt-get remove -y eosio
  sudo apt-get update
  sudo apt-get install -y "./eosio_${EOS_VERSION}-1-${EOS_SYSTEM_TYPE}.deb"
  rm "./eosio_${EOS_VERSION}-1-${EOS_SYSTEM_TYPE}.deb"

}
installeosdev() {
  EOS_VERSION=${1:-$EOS_DEFAULT_VERSION}
  DEB_FILE_NAME="./eosio_${EOS_VERSION}-1-${EOS_SYSTEM_TYPE}.deb"
  DEB_URL="https://github.com/EOSIO/eos/releases/download/v${EOS_VERSION}/eosio_${EOS_VERSION}-1-${EOS_SYSTEM_TYPE}.deb"
  if [[ -f "/usr/opt/eosio/$EOS_VERSION" ]]
  then
    echo "EOS Version $EOS_VERSION already exists on your system"
    if [[ -f "/usr/opt/eosio/$EOS_VERSION/bin/nodeos" ]]
    then
      echo "EOS Version $EOS_VERSION nodeos binary already exists on your system"
    else
      echo "ERROR: EOS Version exists, but missing nodeos binary files: /usr/opt/eosio/$EOS_VERSION/bin/nodeos"
      exit 1
    fi
  fi
  curl -L -o $DEB_FILE_NAME $DEB_URL


  sudo mkdir -p /usr/opt/eosio/$EOS_VERSION/tmp
  sudo mkdir -p /usr/opt/eosio/$EOS_VERSION/bin
  sudo dpkg-deb -xv $DEB_FILE_NAME /usr/opt/eosio/$EOS_VERSION/tmp
  sudo cp /usr/opt/eosio/$EOS_VERSION/tmp/usr/opt/eosio/$EOS_VERSION/bin/* /usr/opt/eosio/$EOS_VERSION/bin
  sudo rm -rf ./usr/opt/eosio/$EOS_VERSION/tmp
  echo "NODEOS=/usr/opt/eosio/$EOS_VERSION/bin/nodeos"



}
setupeosdir() {
  DIR_CODE=$1
  DIR_PATH="/opt/mainnet/$DIR_CODE"
  OWNER_USER=${2:-$USER}
  sudo mkdir -p $DIR_PATH
  sudo cp $BASH_FILE_ME "$DIR_PATH/rpdgds.sh"
  sudo chmod +x "$DIR_PATH/rpdgds.sh"
  echo "$EOS_GENESIS_JSON" | sudo tee "$DIR_PATH/genesis.json" > /dev/null
  echo "$EOS_LOGGING_JSON" | sudo tee "$DIR_PATH/logging.json" > /dev/null
  sudo chown $OWNER_USER:$OWNER_USER $DIR_PATH
  sudo chown $OWNER_USER:$OWNER_USER $DIR_PATH/*
}
stopeosgraceful() {
  DATADIR="${1:-$PWD}"
  if [ -f $DATADIR"/nodeos.pid" ]; then
    pid=$(cat $DATADIR"/nodeos.pid")
    echo $pid
    kill $pid || echo "$pid already killed!"

    if [ $? -ne 0 ]; then
        exit 1
    fi

    rm -r $DATADIR"/nodeos.pid"

    echo -ne "Stopping Nodeos"

    while true; do
        [ ! -d "/proc/$pid/fd" ] && break
        echo -ne "."
        sleep 1
    done
    echo -ne "\rNodeos stopped. \n"
  fi
}
starteos() {
  DATADIR="${1:-$PWD}"
  NODEOS="${2:-nodeos}"

  stopeosgraceful $DATADIR
  $NODEOS --data-dir $DATADIR --config-dir $DATADIR -l $DATADIR/logging.json >> $DATADIR/log.txt 2>&1 & echo $! > $DATADIR/nodeos.pid
}
starteossnapshot() {
  SNAPSHOT_BIN_FILE="${1}"
  DATADIR="${2:-$PWD}"
  NODEOS="${3:-nodeos}"

  stopeosgraceful $DATADIR
  $NODEOS --data-dir $DATADIR --snapshot $SNAPSHOT_BIN_FILE --config-dir $DATADIR -l $DATADIR/logging.json >> $DATADIR/log.txt 2>&1 & echo $! > $DATADIR/nodeos.pid
}
dlLatestSnapshotAndStart() {
  DATADIR="${1:-$PWD}"
  NODEOS="${2:-nodeos}"

  stopeosgraceful $DATADIR
  SNAP_URL=$(wget -qO- https://gitlab.com/snaprapid/snaps/-/raw/master/latest.txt)
  SNAP_FILE_GZ=$(echo $SNAP_URL | sed 's/.*\///')
  SNAP_FILE_BIN=$(echo $SNAP_FILE_GZ | sed 's/\.gz$//')
  echo $SNAP_FILE_BIN
  echo $SNAP_FILE_GZ
  SNAPSHOT_BIN_FILE="$PWD/${SNAP_FILE_BIN}"
  wget "$SNAP_URL"
  gzip -d $SNAP_FILE_GZ
  stopeosgraceful $DATADIR
  $NODEOS --data-dir $DATADIR --snapshot $SNAPSHOT_BIN_FILE --config-dir $DATADIR -l $DATADIR/logging.json >> $DATADIR/log.txt 2>&1 & echo $! > $DATADIR/nodeos.pid
}
sub_help() {

  echo -e "\n\e[107m\n\n\e[34m  ############   \e[31m       ##        \e[35m       ##        \n\e[34m       ##        \e[31m       ##        \e[35m       ##        \n\e[34m       ##        \e[31m       ##        \e[35m ##############  \n\e[34m       ##        \e[31m       ##        \e[35m       ##        \n\e[34m       ##        \e[31m       ##        \e[35m   ###########   \n\e[34m       ##        \e[31m  #############  \e[35m   #   ##   #    \n\e[34m       ##        \e[31m       ##        \e[35m   ##########    \n\e[34m ##############  \e[31m       ###       \e[35m       ##        \n\e[34m       ##        \e[31m      ## #       \e[35m  ############   \n\e[34m       ##        \e[31m      ## ##      \e[35m       ##   ##   \n\e[34m       ##        \e[31m     ##   #      \e[35m ############### \n\e[34m       ##        \e[31m     ##   ##     \e[35m       ##   ##   \n\e[34m       ##        \e[31m    ##     ##    \e[35m  ############   \n\e[34m       ##        \e[31m   ##       ###  \e[35m       ##        \n\e[34m       ##        \e[31m  ##         ### \e[35m     ####        \n\e[34m       ##        \e[31m #            #  \e[35m       #          \n\e[39m\e[49m\n"
  
  echo -e "\xE5\x92\xB1\xE4\xBB\xAC\xE5\xB9\xB2\xE5\xA4\xA7\xE4\xBA\x8B, \xE6\xB2\xA1\xE6\x97\xB6\xE9\x97\xB4\xE8\xBE\x93\xE5\x85\xA5\xE4\xBB\x80\xE4\xB9\x88\xE5\x91\xBD\xE4\xBB\xA4"
  echo "Writing commands, ain't nobody got time for that!"
  echo -e "Usage:\n\n./rpdgds.sh firstrun <new eos user> <core version of eos> <dir id>\n./rpdgds.sh startlatestsnap <datadir (optional, default is PWD)> <path to nodeos binary (optional)>\n./rpdgds.sh startsnap <snapshot_bin_abs_path> <datadir (optional, default is PWD)> <path to nodeos binary (optional)>\n./rpdgds.sh stop <datadir (optional, default is PWD)>\n./rpdgds.sh start <datadir (optional, default is PWD)>\n./rpdgds.sh restart <datadir (optional, default is PWD)>\n"
}
sub_firstrun() {
  NEW_EOS_USER=${1:-eos123}
  EOS_VERSION=${2:-$EOS_DEFAULT_VERSION}
  DIR_ID=${3:-$EOS_VERSION}
  setupdeps
  setupsshuser $NEW_EOS_USER
  setupeosdir $DIR_ID $NEW_EOS_USER
  installeosnormal $EOS_VERSION
}
sub_installdev() {
  NEW_EOS_VERSION=$1
  installeosdev $NEW_EOS_VERSION
}
sub_restart() {
  echo "not implemented"
  exit 1

}
sub_start() {
  starteos $1 $2

}
sub_startsnap() {
  starteossnapshot $1 $2 $3
}
sub_stop() {
  stopeosgraceful $1
}
sub_startlatestsnap() {
  dlLatestSnapshotAndStart $1 $2
}

subcommand=$1
case $subcommand in
    "" | "-h" | "--help")
        sub_help
        ;;
    *)
        shift
        sub_${subcommand} $@
        if [ $? = 127 ]; then
            echo "Error: '$subcommand' is not a known subcommand." >&2
            echo "       Run '$ProgName --help' for a list of known subcommands." >&2
            exit 1
        fi
        ;;
esac
