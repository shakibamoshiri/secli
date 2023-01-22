#!/bin/bash

set -euo pipefail

declare _hub="${1:?hub name}";
declare _target="${2:?target name}"
declare -a list_users=(${@:3});

if (( ${#list_users[0]} == 0 )); then
    printf 'at least one user name is needed\n';
    exit 1;
fi

function block_user(){
    declare username;
    username="${1:?user name is needed}";

    ./secli GetUser  --hub $_hub --user $username | \
    ./secli config -f admin.yaml -t $_target | \
    ./secli apply | \
    jq '.result."policy:Access_bool"=false' | \
    ./secli SetUser | \
    ./secli config -f admin.yaml -t $_target | \
    ./secli apply | \
    jq -c '{ "task": "done", "user": .result.Name_str, "access": .result."policy:Access_bool" }'
}

./secli EnumUser --hub $_hub | \
    ./secli config -f admin.yaml -t $_target | \
    ./secli apply | \
    jq -r '.result.UserList[].Name_str' > list.txt


while read username; do
    for a_user in "${list_users[@]}"; do
        if [[ $username == $a_user ]]; then
            block_user $username;
        fi
    done
done < list.txt;

