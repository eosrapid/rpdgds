# rpdgds.sh
The fastest way to spin up an EOSIO node. &lt;咱们干大事, 没时间输入什么命令>


# Useful Commands
***Note all of these commands should be ran in your node's data directory (the folder with blocks and state)

## Start your node
```bash
./rpdgds.sh start
```

## Stop your node
```bash
./rpdgds.sh stop
```

## Restart your node with the latest snapshot from Rapid Snaps
```bash
./rpdgds.sh stop && rm -rf ./blocks && rm -rf ./state && ./rpdgds.sh startlatestsnap
```


## Install rpdgds on a node that already has EOSIO installed
```bash
cd <your eosio data dir (the directory containing the blocks and state folder)>
wget https://raw.githubusercontent.com/eosrapid/rpdgds/master/rpdgds.sh
chmod +x ./rpdgds.sh
```

# Install rpdgds+EOSIO 2.0.5 on a clean AWS node (No nodeos/eosio software previously installed)

### Step 1.
Run the command shown below
```bash
wget https://raw.githubusercontent.com/eosrapid/rpdgds/master/rpdgds.sh && chmod +x rpdgds.sh
```

### Step 2.
Open rpdgds.sh in your favorite text editor and modify the config at the top of the file if needed, in particular
```bash
EOS_SYSTEM_TYPE="ubuntu-16.04_amd64" # replace this with "ubuntu-18.04_amd64" if you are on ubuntu 18.04
EOS_DEFAULT_VERSION="2.0.5" # replace this with another version of EOSIO if you don't want 2.0.5

MICRO_SYSTEM_TYPE="linux64"
MICRO_DEFAULT_VERSION="2.0.0"

EXISTING_AUTHORIZED_KEYS_FILE="/home/ubuntu/.ssh/authorized_keys" # replace this with the path to your ssh public key so you can ssh into the new non root account we will make for running eos, defaults to the path to the user "ubuntu"'s authorized pub key

CHRONY_SERVER="server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4" # if you are on aws, leave this be, if you are on baremetal or another cloud, replace this with your preferred chrony time server (use syntax found in /etc/chrony/chrony.conf)
```

### Step 3.
Create your eos non root user account automatically and install EOS
```bash
./rpdgds.sh firstrun myeosuser && cp ./rpdgds.sh /opt/mainnet/2.0.5
```

### Step 4.
In your EOS data directory (should be /opt/mainnet/2.0.5), create a file called config.ini using this template: [config.ini template](https://gist.githubusercontent.com/eosrapid/a9101ed726e92acb2d218d58e77441c2/raw/f37a141763744175f4cdf6f6b297dd5edac3a174/config.ini).
***Note you must read through this file and update any values marked as such in the file***

### Step 5.
Start up your node and sync it to the mainnet with the latest snapshot from Rapid Snaps!
```bash
cd /opt/mainnet/2.0.5 && ./rpdgds.sh startlatestsnap
```

### Step 6.
(Optional) View your logs
```bash
tail -f ./logs.txt
```

### Step 7. Check out your node's API!
(Optional) View your logs
```bash
curl localhost:8888/v1/chain/get_info
```

