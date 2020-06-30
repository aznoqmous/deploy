#!/bin/bash
# set -o nounset
# set -o xtrace
set -o errexit

trap ctrl_c INT
ctrl_c(){
    echo -e "\nBye bye !"
    exit
}

test_ssh(){
    ssh_creds="$1"
    success=$(ssh -t "$ssh_creds" "echo 'ok'" 2>/dev/null | grep 'ok')
    echo "$success"
}

init(){
    echo "New deploy configuration $(pwd)"
    read -p "Server (leave blank to deploy locally): " server
    read -p "Deployment path (default: $(pwd)): " path
    path=${path:-$(pwd)}
    read -p "Server user (leave blank to keep rights): " user
    read -p "Specify folders to ignore separated by comas (ex: vendor,node_modules,...): " ignored

    echo "server $server" > "$config_file"
    echo "path $path" >> "$config_file"
    echo "user $user" >> "$config_file"
    echo ".deploy*" >> "$ignore_file"
    echo $ignored | tr "," "\n" >> "$ignore_file"
}

state(){
    if [[ ! -d $(dirname "$state_file") ]]; then
        mkdir -p $(dirname "$state_file")
    fi
    if [[ ! -f "$state_file" ]]; then
        touch "$state_file"
    fi

    value="$1"
    if [[ -z "$value" ]]; then
        cat "$state_file"
    else
        echo "$value" > "$state_file"
    fi
}

dsync(){
    server="$1"
    path="$2"
    ignore_file="$3"
    if [[ -z "$server" ]]
    then
        # local deployment
        destinationPath="$path"
        mkdir -p "$destinationPath"
        state 0
        if [[ -f "$ignore_file" ]]
        then
            rsync -rl --info=progress2 --exclude-from="$ignore_file" . "$destinationPath" > /dev/null 2> /dev/null
        else
            rsync -rl --info=progress2 . "$destinationPath" > /dev/null 2> /dev/null
        fi
        state 1
    else
        # remote deployment
        destinationPath="$server:$path"
        state 0
        if [[ -f "$ignore_file" ]]
        then
            rsync -rl --info=progress2 --exclude-from="$ignore_file" -e ssh . "$destinationPath" > /dev/null 2> /dev/null
        else
            rsync -rl --info=progress2 -e ssh . "$destinationPath" > /dev/null 2> /dev/null
        fi
        state 1
    fi
}

# RSYNC FILES
deploy(){
    if [[ ! -z "$server" ]]
    then
        if [[ -z $(test_ssh "$server") ]]
        then
            echo "SSH connexion failed."
            exit
        fi
    fi

    dsync "$server" "$path" "$ignore_file" &

    i=0
    symbols=('\' '|' '/' '—')
    while [[ $(state) = 0 ]]; do
        char=$(($i%4))
        i=$(($i+1))
        printf "${symbols[$char]} deploying current directory to $server $path...\r"
    done

    if [[ ! -z $user ]]
    then
        ssh -t "$server" "chown -R $user. $path" > /dev/null 2> /dev/null
    fi

}

lastdeploy=0
deploy_on_update(){
    lastupdate=$(lastupdate)
    human_date=$(date -d @$lastupdate)
    if [ $lastdeploy -lt $lastupdate ]; then
        printf ">                      \r"
        deploy
        lastdeploy=$lastupdate
        echo "- $human_date              "
        printf "Waiting for changes... \r"
    fi
}

lastupdate(){
    lastfile=$(find . -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")
    lastupdate=$(stat -c "%Y" "$lastfile")
    echo "$lastupdate";
}

#  ARGUMENTS
config_file=".deploy"
ignore_file=".deploy_ignore"
state_file="/tmp/deploy/state"
mode=$1
deploy_pre_script=".deploy_pre"
deploy_post_script=".deploy_post"

# BUILD CONFIG
if [[ ! -f "$config_file" ]]
then
    init "$config_file"
fi

# GET CONFIG
while read var value
do
    export "$var"="$value"
done < "$config_file"

# DO
if [[ -z "$mode" ]]; then
    if [[ -f "$deploy_pre_script" ]]; then
        echo "Running pre deployment script"
        chmod +x "$deploy_pre_script"
        . "$(pwd)/$deploy_pre_script"
    fi
    deploy
    echo "Transfer done                                                        "
    if [[ -f "$deploy_post_script" ]]; then
        echo "Running post deployment script"
        chmod +x "$deploy_post_script"
        . "$(pwd)/$deploy_post_script"
    fi
elif [[ $mode = 'watch' ]]; then
    printf "Sending...\r"
    while true;
    do
        deploy_on_update
        sleep 1
    done
elif [[ $mode = 'config' ]]; then
    if [[ -f "$config_file" ]]; then
        cat "$config_file"
    else
        echo "No deploy configuration found in current folder"
    fi
fi
