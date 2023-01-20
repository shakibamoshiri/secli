#!/bin/bash

set -euo pipefail

declare _hub="${1:?hub name}";
declare _target="${2:?target name}"
declare -a list_users=(${@:3});

if (( ${#list_users[0]} == 0 )); then
    printf 'at least one user name is needed\n';
    exit 1;
fi

function get_user(){
    declare username;
    username="${1:?user name is needed}";

    ./secli GetUser --hub $_hub --user $username | \
    ./secli config -f admin.yaml -t $_target | \
    ./secli apply | \
    ./secli parse -m GetUser
}

./secli EnumUser --hub $_hub | \
    ./secli config -f admin.yaml -t $_target | \
    ./secli apply | \
    jq -r '.result.UserList[].Name_str' > list.txt


while read username; do
    for a_user in "${list_users[@]}"; do
        if [[ $username == $a_user ]]; then
            get_user $username;
        fi
    done
done < list.txt;

