#!/bin/bash

################################################################################
#
#                  (_ ) _
#   ___   __    ___ | |(_)
# /  __)/ __ \/ ___)| || |
# \__  \  ___/ (___ | || |
# (____/\____)\____)___)_)
# 
# pure Bash CLI to manage SoftEther VPN Server using JSON-RPC
# 
# https://github.com/shakibamoshiri/secli
# 
# project
# https://github.com/SoftEtherVPN/SoftEtherVPN
#
# SoftEther VPN Server JSON-RPC API Suite Document
# https://github.com/SoftEtherVPN/SoftEtherVPN/tree/master/developer_tools/vpnserver-jsonrpc-clients
#
################################################################################
#
# bash strict mode
#
################################################################################
private::strict_mode(){
    set -T # inherit DEBUG and RETURN trap for functions
    set -C # prevent file overwrite by > &> <>
    set -E # inherit -e
    set -e # exit immediately on errors
    set -u # exit on not assigned variables
    set -o pipefail # exit on pipe failure
}
private::strict_mode;

################################################################################
#
# check for dependencies and commands
#
################################################################################
private::import(){
    declare -r command_name=$1;

    if ! which $command_name > /dev/null 2>&1; then
        printf 'command %s not found\n' $command_name;
        printf 'install %s from:\n' $command_name;
        case $command_name in
            yq )
                echo 'https://github.com/mikefarah/yq';
            ;;
            jq )
                echo 'https://stedolan.github.io/jq/download/';
            ;;
            perl | printf | echo )
                echo 'your package manager, apt-get, yum, dnf, apk, etc';
            ;;
            * )
                echo 'your OS repository or search the Internet';
            ;;
        esac
        exit 1;
    fi
}

private::import yq
private::import jq
private::import perl
private::import printf
private::import echo

#four functions to change output in color
private::info() { printf "\033[1;34m${*}\033[0m\n"; }
private::warn() { printf "\033[1;33m${*}\033[0m\n" 1>&2; }
private::error(){ printf "\033[1;31m${*}\033[0m\n" 1>&2; }
private::title(){ printf "\033[1;37m${*}\033[0m\n"; }

# immutable variables
declare -ir ERR_EXPR_FAILED=1;
declare -ir ERR_FILE_NOT_FOUND=2;
declare -ir ERR_OPTION_NOT_FOUND=3;
declare -ir EXIT_NO_ERR=0;
declare -ir CLI_PPID=$$;

# declare -rA SUBCMD=([help]=help [config]=config [Test]=Test [EnumUser]=EnumUser);
declare -r PS4='debug($LINENO) ${FUNCNAME[0]:+${FUNCNAME[0]}}(): ';
declare -r CLI_NAME='tun2ns';
declare -r CLI_VERSION='0.0.1';
declare -r CLI_INSTALL_PATH='/usr/local/bin';
declare -r API_PATH="${PWD}/api";
declare -r DOT_ANSISHELL='tun2ns';
declare -r HELP_OFFSET=20;
declare -r ANSISHELL_HEADER='
                  (_ ) _
   ___   __    ___ | |(_)
 /  __)/ __ \/ ___)| || |
 \__  \  ___/ (___ | || |
 (____/\____)\____)___)_)

SE CLI to manage SE server';

# art
# https://textfancy.com/text-art/

declare SEconf='';
declare OUT_FROMAT=default;
declare SCRIPT_DEBUG_FLAG=false;
################################################################################
#
# public/private function used by commands
#
################################################################################
function __error_handing__(){
    local last_status_code=$1;
    local error_line_number=$2;
    echo 1>&2 "Error - exited with status $last_status_code at line $error_line_number";
    perl -slne 'if($.+5 >= $ln && $.-4 <= $ln){ $_="$. $_"; s/$ln/">" x length($ln)/eg; s/^\D+.*?$/$&/g;  print}' -- -ln=$error_line_number $0
    echo;
}

trap '__error_handing__ $? $LINENO' ERR
# trap '__debug_handing__ $? $LINENO' DEBUG
# trap '__exit_handing__ $?' INT TERM EXIT

private::curl_request(){
    private::strict_mode;
    declare output_format
    declare curl_data;
    output_format="${1:?An output format is needed}";
    curl_data="${2:?RPC-JSON is needed}";

    case ${output_format} in
        json )
            curl -sL --insecure  -X POST -H "X-VPNADMIN-PASSWORD: ${SEserver[pass]}"  https://${SEserver[addr]}:${SEserver[port]}/api/ -d "${curl_data}" | jq '.'
        ;;
        yaml )
            curl -sL --insecure  -X POST -H "X-VPNADMIN-PASSWORD: ${SEserver[pass]}"  https://${SEserver[addr]}:${SEserver[port]}/api/ -d "${curl_data}" | jq '.' | yq -Po yaml
        ;;
        default )
            curl -sL --insecure  -X POST -H "X-VPNADMIN-PASSWORD: ${SEserver[pass]}"  https://${SEserver[addr]}:${SEserver[port]}/api/ -d "${curl_data}";
        ;;
        * )
            printf "'%s' output format not found. see help\n" $1;
            exit $ERR_EXPR_FAILED;
        ;;
    esac
}

public::apply(){
    private::strict_mode;

    # if [[ ${SEserver[addr]} == '' ]]; then
    #     printf "use 'config' --file file.yaml --target name before using 'apply' command\n";
    #     exit $ERR_EXPR_FAILED;
    # fi

    private::apply(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-f  | --format" "output format: default, json, yaml";

        exit ${1:-1};
    }

    if (( ${#} == 0 )); then
        if ! [[ -p /dev/stdin ]]; then
            private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
        fi
    fi

    declare se_data='';
    if [[ -p /dev/stdin ]]; then
        se_data=$(< /dev/stdin);
    fi

    declare __format=default;

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::${FUNCNAME/*:/} 0;
                shift 1;
            ;;
            -f | --format )
                __format="${2:?Error: a format <default|json|yaml> is needed}";
                shift 2;
            ;;
            * )
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done
    
    : __format="${__format:?Error: a format <default|json|yaml> is needed}";
    private::debug $LINENO '--format' "'${__format}'";

    declare -A SEserver=([addr]= [port]= [pass]=);
    declare rpc_json_method='';
    SEserver[addr]=$(yq '.se_cred.address' <<< "$se_data");
    SEserver[port]=$(yq '.se_cred.port' <<< "$se_data");
    SEserver[pass]=$(yq '.se_cred.password' <<< "$se_data");

    curl_data=$(jq '.rpc_json' <<< "$se_data");
    rpc_json_method=$(jq '.rpc_json.method' <<< "$se_data");

    case ${__format} in
        json )
            curl -sL --insecure  -X POST -H "X-VPNADMIN-PASSWORD: ${SEserver[pass]}"  https://${SEserver[addr]}:${SEserver[port]}/api/ -d "${curl_data}" | jq '.'
        ;;
        yaml )
            curl -sL --insecure  -X POST -H "X-VPNADMIN-PASSWORD: ${SEserver[pass]}"  https://${SEserver[addr]}:${SEserver[port]}/api/ -d "${curl_data}" | jq '.' | yq -Po yaml
        ;;
        default )
            curl -sL --insecure  -X POST -H "X-VPNADMIN-PASSWORD: ${SEserver[pass]}"  https://${SEserver[addr]}:${SEserver[port]}/api/ -d "${curl_data}" | jq "{method: $rpc_json_method} + .";
        ;;
        * )
            printf "'%s' output format not found. see help\n" $1;
            exit $ERR_EXPR_FAILED;
        ;;
    esac
}






public::Test(){
    declare SEmethod;
    SEmethod=${FUNCNAME/*:/};

    declare -x __params='
    "params": {
        "IntValue_u32": 0
    }';

    yq -n '{"jsonrpc": "2.0"} + {"id":"rpc_call_id"} + {"method":"'"$SEmethod"'"} + { eval(strenv(__params)) }' -Po json
}

public::GetServerInfo(){
    declare SEmethod;
    SEmethod=${FUNCNAME/*:/};
    yq -Po json  -n '{"jsonrpc": "2.0", "id": "rpc_call_id", "method": "'"${SEmethod}"'", "params": {}}';
}

public::GetServerStatus(){
    declare SEmethod;
    SEmethod=${FUNCNAME/*:/};
    yq -Po json  -n '{"jsonrpc": "2.0", "id": "rpc_call_id", "method": "'"${SEmethod}"'", "params": {}}';
}

public::CreateListener(){
    private::strict_mode;

    private::CreateListener(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-p  | --port" "a valid port number on SE server";
        printf "%-${HELP_OFFSET}s %s\n" "-e  | --enable" "enable port number on SE server (default=true)";

        exit ${1:-1};
    }

    if (( ${#} == 0 )); then
        private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    fi
    
    declare __port='';
    declare __enable='true';

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::${FUNCNAME/*:/} 0;
                shift 1;
            ;;
            -p | --port )
                __port="${2:?Error: a port <number> is needed}";
                shift 2;
            ;;
            -e | --enable )
                __enable="${2:?Error: true or false option is needed}";
                shift 2;
            ;;
            * )
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done
    
    : __port="${__port:?Error: a port <number> is needed}";
    private::debug $LINENO '--port' "'${__port}'";
    private::debug $LINENO '--enable' "'${__enable}'";

    declare SEmethod;
    SEmethod=${FUNCNAME/*:/};

    declare -x __params='"params": {
        "Port_u32": '$__port',
        "Enable_bool": '$__enable'
    } ';

    yq -n '{"jsonrpc": "2.0"} + {"id":"rpc_call_id"} + {"method":"'"$SEmethod"'"} + { eval(strenv(__params)) }' -Po json
}

public::EnumListener(){
    declare SEmethod;
    SEmethod=${FUNCNAME/*:/};
    yq -Po json  -n '{"jsonrpc": "2.0", "id": "rpc_call_id", "method": "'"${SEmethod}"'", "params": {}}';
}

public::DeleteListener(){
    private::strict_mode;

    private::DeleteListener(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-p  | --port" "a valid port number on SE server";

        exit ${1:-1};
    }

    if (( ${#} == 0 )); then
        private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    fi

    declare __port='';

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::${FUNCNAME/*:/} 0;
                shift 1;
            ;;
            -p | --port )
                __port="${2:?Error: a port <number> is needed}";
                shift 2;
            ;;
            * )
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done
    
    : __port="${__port:?Error: a port <number> is needed}";
    private::debug $LINENO '--port' "'${__port}'";

    declare SEmethod;
    SEmethod=${FUNCNAME/*:/};

    declare -x __params='"params": {
        "Port_u32": '$__port'
    } ';

    yq -n '{"jsonrpc": "2.0"} + {"id":"rpc_call_id"} + {"method":"'"$SEmethod"'"} + { eval(strenv(__params)) }' -Po json
}

public::EnableListener(){
    private::strict_mode;

    private::EnableListener(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-p  | --port" "a valid port number on SE server";
        printf "%-${HELP_OFFSET}s %s\n" "-e  | --enable" "enable port number on SE server (default=true)";

        exit ${1:-1};
    }

    if (( ${#} == 0 )); then
        private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    fi
    
    declare __port='';
    declare __enable='true';

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::${FUNCNAME/*:/} 0;
                shift 1;
            ;;
            -p | --port )
                __port="${2:?Error: a port <number> is needed}";
                shift 2;
            ;;
            -e | --enable )
                __enable="${2:?Error: true or false option is needed}";
                shift 2;
            ;;
            * )
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done
    
    : __port="${__port:?Error: a port <number> is needed}";
    private::debug $LINENO '--port' "'${__port}'";
    private::debug $LINENO '--enable' "'${__enable}'";

    declare SEmethod;
    SEmethod=${FUNCNAME/*:/};

    declare -x __params='"params": {
        "Port_u32": '$__port',
        "Enable_bool": '$__enable'
    } ';

    yq -n '{"jsonrpc": "2.0"} + {"id":"rpc_call_id"} + {"method":"'"$SEmethod"'"} + { eval(strenv(__params)) }' -Po json
}

public::CreateUser(){
    private::strict_mode;
    private::CreateUser(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-H  | --hub" "a valid hub name on SE server";
        printf "%-${HELP_OFFSET}s %s\n" "-u  | --user" "a valid user name";
        printf "%-${HELP_OFFSET}s %s\n" "-p  | --pass" "a password to set for user name";
        printf "%-${HELP_OFFSET}s %s\n" "-r  | --realname" "full name for a user";
        printf "%-${HELP_OFFSET}s %s\n" "-n  | --note" "note  for a user";
        printf "%-${HELP_OFFSET}s %s\n" "-e  | --e-time" "expire time in days";
        printf "%-${HELP_OFFSET}s %s\n" "-a  | --auth-type" "type for authentication [0-5], default=1";
        printf "%-${HELP_OFFSET}s %s\n" "-P  | --p-rule" "enable policy rules for a user [=false|true]";
        printf "%-${HELP_OFFSET}s %s\n" "-Pa | --p-access" "policy: access for a user [=true|false]";
        printf "%-${HELP_OFFSET}s %s\n" "-Pp | --p-fix-pass" "policy: fix password for a user [=true|false]";
        printf "%-${HELP_OFFSET}s %s\n" "-Pl | --p-mulit-l" "policy: multiple login  for a user [=1]";
        printf "%-${HELP_OFFSET}s %s\n" "-Pd | --p-max-dl" "policy: max download speed";

        exit ${1:-1};
    }

    if (( ${#} == 0 )); then
        private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    fi

    declare __hub='';
    declare __user_name='';
    declare __user_pass='';
    declare __real_name='';
    declare -i __user_note=1;
    declare __expire_time=$(date +%FT%T -d "+29 days");
    declare __auth_type=1;
    declare __policy_rule='true';
    declare __policy_access='true';
    declare __policy_fix_pass='true';
    declare __policy_multi_login=1;
    declare -i __policy_max_download=0;
    declare -ir __one_gig=1073741824;

    # policy:MaxConnection_u32
    declare __policy_max_tcp_con=32;
    # policy:TimeOut_u32
    declare __policy_timeout=20

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::split_help 0;
            ;;
            -H | --hub )
                __hub="${2:?Error: a hub <name> is needed}";
                shift 2;
            ;;
            -u | --user )
                __user_name="${2:?Error: a user <name> is needed}";
                shift 2;
            ;;
            -p | --pass )
                __user_pass="${2:?Error: a user <password> is needed}";
                shift 2;
            ;;
            -r | --real )
                __real_name="${2:?Error: a full <name> is needed}";
                shift 2;
            ;;
            -n | --note )
                __user_note="${2:?Error: a note is needed}";
                shift 2;
            ;;
            -e | --e-time )
                __expire_time="${2:?Error: a <number> is needed}";
                __expire_time=$(date +%FT%T -d "+${__expire_time} days");
                shift 2;
            ;;
            -a | --auth-type )
                __auth_type="${2:?Error: a <number> is needed [0-5}";
                shift 2;
            ;;
            -P | --p-rule )
                __policy_rule="${2:?Error: a <true/false> is needed}";
                shift 2;
            ;;
            -Pa | --p-access )
                __policy_access="${2:?Error: a <true/false> is needed}";
                shift 2;
            ;;
            -Pp | --p-fix-pass )
                __policy_fix_pass="${2:?Error: a <true/false> is needed}";
                shift 2;
            ;;
            -Pl | --p-mulit-l )
                __policy_multi_login="${2:?Error: a <true/false> is needed}";
                shift 2;
            ;;
            -Pd | --p-max-dl )
                __policy_max_download="${2:?Error: a <number> is needed}";
                shift 2;
            ;;

            * )
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done
    
    : __hub="${__hub:?Error: __hub has not been set}";
    : __user_name="${__user_name:?Error: __user_name has not been set}";
    : __user_pass="${__user_pass:?Error: __user_pass has not been set}";
    : __real_name="${__real_name:?Error: __real_name has not been set}";

    private::debug $LINENO '--hub' "'${__hub}'";
    private::debug $LINENO '--user' "'${__user_name}'";
    private::debug $LINENO '--pass' "'${__user_pass}'";
    private::debug $LINENO '--real' "'${__real_name}'";
    private::debug $LINENO '--note' "'$((${__user_note} * $__one_gig))'";
    private::debug $LINENO '--p-rule' "'${__policy_rule}'";
    private::debug $LINENO '--p-access' "'${__policy_access}'";
    private::debug $LINENO '--p-fix-pass' "'${__policy_fix_pass}'";
    private::debug $LINENO '--p-mulit-login' "'${__policy_multi_login}'";
    private::debug $LINENO '--p-max-dl' "'${__policy_max_download}'";

    declare -x __params=' "params": {
        "HubName_str": "'"${__hub}"'",
        "Name_str": "'"${__user_name}"'",
        "Realname_utf": "'"${__real_name}"'",
        "Note_utf": "'"$((${__user_note} * $__one_gig))"'",
        "ExpireTime_dt": "'"${__expire_time}"'",
        "AuthType_u32": '${__auth_type}',
        "Auth_Password_str": "'"${__user_pass}"'",
        "UsePolicy_bool": '${__policy_rule}',
        "policy:Access_bool": '${__policy_access}',
        "policy:MaxConnection_u32": 32,
        "policy:TimeOut_u32": 20,
        "policy:FixPassword_bool": true,
        "policy:MultiLogins_u32": '${__policy_multi_login}',
        "policy:MaxDownload_u32": '${__policy_max_download}'
    }';

    yq -n '{"jsonrpc": "2.0"} + {"id":"rpc_call_id"} + {"method":"'"${FUNCNAME/*:/}"'"} + { eval(strenv(__params)) }' -Po json
}

public::SetUser(){
    private::SetUser(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-H  | --hub" "a valid hub name on SE server";
        printf "%-${HELP_OFFSET}s %s\n" "-u  | --user" "a valid user name";
        printf "%-${HELP_OFFSET}s %s\n" "-p  | --pass" "a password to set for user name";
        printf "%-${HELP_OFFSET}s %s\n" "-r  | --realname" "full name for a user";
        printf "%-${HELP_OFFSET}s %s\n" "-n  | --note" "note  for a user";
        printf "%-${HELP_OFFSET}s %s\n" "-a  | --auth-type" "type for authentication [0-5], default=1";
        printf "%-${HELP_OFFSET}s %s\n" "-P  | --p-rule" "enable policy rules for a user [=false|true]";
        printf "%-${HELP_OFFSET}s %s\n" "-Pa | --p-access" "policy: access for a user [=true|false]";
        printf "%-${HELP_OFFSET}s %s\n" "-Pf | --p-fix-pass" "policy: fix password for a user [=true|false]";
        printf "%-${HELP_OFFSET}s %s\n" "-Pm | --p-mulit-login" "policy: multiple login  for a user [=1]";

        exit ${1:-1};
    }

    # declare quary_result='';
    # if (( ${#} == 0 )); then
    #     private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    # fi


    declare -x rpc_json;
    if (( ${#} == 0 )); then
        if ! [[ -p /dev/stdin ]]; then
            private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
        fi
    fi

    if [[ -p /dev/stdin ]]; then
        rpc_json=$(< /dev/stdin);

        if [[ -z $rpc_json ]]; then
            printf "rpc_json is null/empty\n";
            exit $ERR_EXPR_FAILED;
        fi
    fi

    # echo quary_result "$quary_result"
    # exit 0;

    # if ! [[ -p /dev/stdin ]]; then
    #     private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    # else
    #     quary_result=$(< /dev/stdin);
    # fi

    declare __hub='';
    declare __user_pass='';
    declare __real_name='';
    declare __user_note='';
    declare __auth_type=1;
    declare __policy_rule='false';
    declare __policy_access='true';
    declare __policy_fix_pass='true';
    declare __policy_multi_login=1;

    # policy:MaxConnection_u32
    declare __policy_max_tcp_con=32;
    # policy:TimeOut_u32
    declare __policy_timeout=20

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::${FUNCNAME/*:/} 0;
            ;;
            -h | --hub )
                __hub="${2:?Error: a hub <name> is needed}";
                shift 2;
                rpc_json=$(yq '.result.HubName_str="'"${__hub}"'"  ' -Po json <<< "$rpc_json");
            ;;
            -p | --user )
                __user_name="${2:?Error: a user <name> is needed}";
                shift 2;
                rpc_json=$(yq '.result.Name_str="'"${__user_name}"'"  ' -Po json <<< "$rpc_json");
            ;;
            -p | --pass )
                __user_pass="${2:?Error: a password is needed}";
                shift 2;
                rpc_json=$(yq '.result.Auth_Password_str="'"${__real_name}"'"  ' -Po json <<< "$rpc_json");
            ;;
            -r | --real )
                __real_name="${2:?Error: a full <name> is needed}";
                shift 2;
                rpc_json=$(yq '.result.Realname_utf="'"${__real_name}"'"  ' -Po json <<< "$rpc_json");
            ;;
            -n | --note )
                __user_note="${2:?Error: a note is needed}";
                shift 2;
                rpc_json=$(yq '.result.Note_utf="'"${__user_note}"'"  ' -Po json <<< "$rpc_json");
            ;;
            -a | --auth-type )
                __auth_type="${2:?Error: a <number> is needed [0-5}";
                shift 2;
                rpc_json=$(yq '.result.AuthType_u32='${__auth_type}'  ' -Po json <<< "$rpc_json");
            ;;
            -P | --p-rule )
                __policy_rule="${2:?Error: a <true/false> is needed}";
                shift 2;
                rpc_json=$(yq '.result.UsePolicy_bool='${__policy_rule}'  ' -Po json <<< "$rpc_json");
            ;;
            -Pa | --p-access )
                __policy_access="${2:?Error: a <true/false> is needed}";
                shift 2;
                rpc_json=$(yq '.result."policy:Access_bool"='${__policy_access}'  ' -Po json <<< "$rpc_json");
            ;;
            -Pf | --p-fix-pass )
                __policy_fix_pass="${2:?Error: a <true/false> is needed}";
                shift 2;
                rpc_json=$(yq '.result."policy:FixPassword_bool"='${__policy_fix_pass}'  ' -Po json <<< "$rpc_json");
            ;;
            -Pm | --p-mulit-login )
                __policy_multi_login="${2:?Error: a <true/false> is needed}";
                shift 2;
                rpc_json=$(yq '.result."policy:MultiLogins_u32"='${__policy_multi_login}' ' -Po json <<< "$rpc_json");
            ;;

            * )
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done
    
    private::debug $LINENO '--real' "'${__real_name}'";
    private::debug $LINENO '--note' "'${__user_note}'";
    private::debug $LINENO '--p-rule' "'${__policy_rule}'";
    private::debug $LINENO '--p-access' "'${__policy_access}'";
    private::debug $LINENO '--p-fix-pass' "'${__policy_fix_pass}'";
    private::debug $LINENO '--p-mulit-login' "'${__policy_multi_login}'";

    # declare -x __params="$(yq '.result' <<< $quary_result | jq '.')";
    declare -x __params="$(yq '.result' <<< "$rpc_json" | jq '.')";
    yq -Po json -n '{"jsonrpc": "2.0"} + {"id":"rpc_call_id"} + {"method":"'"${FUNCNAME/*:/}"'"} + { "params": eval(strenv(__params)) }';
}

public::GetUser(){
    private::strict_mode;
    private::GetUser(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-H  | --hub" "a valid hub name on SE server";
        printf "%-${HELP_OFFSET}s %s\n" "-u  | --user" "a valid user name on SE server";

        exit ${1:-1};
    }

    if (( ${#} == 0 )); then
        private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    fi

    declare __hub='';
    declare __user='';

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::split_help 0;
            ;;
            -H | --hub )
                __hub="${2:?Error: a hub <name> is needed}";
                shift 2;
            ;;
            -u | --user )
                __user="${2:?Error: a user <name> is needed}";
                shift 2;
            ;;
            * )
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done
    
    : __hub="${__hub:?Error: a hub <name> is needed}";
    : __user="${__user:?Error: a user <name> is needed}";

    private::debug $LINENO '--hub' "'${__hub}'";
    private::debug $LINENO '--user' "'${__user}'";

    declare SEmethod;
    SEmethod=${FUNCNAME/*:/};

    declare -x __params='"params": {
        "HubName_str": "'"$__hub"'",
        "Name_str": "'"$__user"'"
    } ';

    yq -n '{"jsonrpc": "2.0"} + {"id":"rpc_call_id"} + {"method":"'"$SEmethod"'"} + { eval(strenv(__params)) }' -Po json
}

public::DeleteUser(){
    private::strict_mode;
    private::GetUser(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-H  | --hub" "a valid hub name on SE server";
        printf "%-${HELP_OFFSET}s %s\n" "-u  | --user" "a valid user name on SE server";

        exit ${1:-1};
    }

    if (( ${#} == 0 )); then
        private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    fi

    declare __hub='';
    declare __user='';

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::split_help 0;
            ;;
            -H | --hub )
                __hub="${2:?Error: a hub <name> is needed}";
                shift 2;
            ;;
            -u | --user )
                __user="${2:?Error: a user <name> is needed}";
                shift 2;
            ;;
            * )
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done
    
    : __hub="${__hub:?Error: a hub <name> is needed}";
    : __user="${__user:?Error: a user <name> is needed}";

    private::debug $LINENO '--hub' "'${__hub}'";
    private::debug $LINENO '--user' "'${__user}'";

    declare SEmethod;
    SEmethod=${FUNCNAME/*:/};

    declare -x __params='"params": {
        "HubName_str": "'"$__hub"'",
        "Name_str": "'"$__user"'"
    } ';

    yq -n '{"jsonrpc": "2.0"} + {"id":"rpc_call_id"} + {"method":"'"$SEmethod"'"} + { eval(strenv(__params)) }' -Po json
}

public::EnumUser(){
    private::strict_mode;
    private::EnumUser(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-H  | --hub" "a valid hub name on SE server";

        exit ${1:-1};
    }

    if (( ${#} == 0 )); then
        private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    fi

    declare __hub='';

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::split_help 0;
            ;;
            -H | --hub )
                __hub="${2:?Error: a hub <name> is needed}";
                shift 2;
            ;;
            * )
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done
    
    : __hub="${__hub:?Error: a hub <name> is needed}";

    private::debug $LINENO '--hub' "'${__hub}'";

    declare SEmethod;
    SEmethod=${FUNCNAME/*:/};

    declare -x __params='"params": {
        "HubName_str": "'"$__hub"'"
    } ';

    yq -n '{"jsonrpc": "2.0"} + {"id":"rpc_call_id"} + {"method":"'"$SEmethod"'"} + { eval(strenv(__params)) }' -Po json
}

public::EnumSession(){
    private::strict_mode;
    private::EnumSession(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-H  | --hub" "a valid hub name on SE server";

        exit ${1:-1};
    }

    if (( ${#} == 0 )); then
        private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    fi

    declare __hub='';

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::split_help 0;
            ;;
            -H | --hub )
                __hub="${2:?Error: a hub <name> is needed}";
                shift 2;
            ;;
            * )
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done

    : __hub="${__hub:?Error: a hub <name> is needed}";

    private::debug $LINENO '--hub' "'${__hub}'";

    declare SEmethod;
    SEmethod=${FUNCNAME/*:/};

    declare -x __params='"params": {
        "HubName_str": "'"$__hub"'"
    } ';

    yq -n '{"jsonrpc": "2.0"} + {"id":"rpc_call_id"} + {"method":"'"$SEmethod"'"} + { eval(strenv(__params)) }' -Po json

}

public::GetSessionStatus(){
    private::strict_mode;
    private::GetSessionStatus(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-H  | --hub" "a valid hub name on SE server";
        printf "%-${HELP_OFFSET}s %s\n" "-u  | --user" "a valid user name on SE server";

        exit ${1:-1};
    }

    if (( ${#} == 0 )); then
        private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    fi

    declare __hub='';
    declare __user='';

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
            -H | --hub )
                __hub="${2:?Error: a hub <name> is needed}";
                shift 2;
            ;;
            -u | --user )
                __user="${2:?Error: a user <name> is needed}";
                shift 2;
            ;;
            * )
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done

    : __hub="${__hub:?Error: a hub <name> is needed}";
    : __user="${__user:?Error: a user <name> is needed}";

    private::debug $LINENO '--hub' "'${__hub}'";
    private::debug $LINENO '--user' "'${__user}'";

    declare SEmethod;
    SEmethod=${FUNCNAME/*:/};

    declare -x __params='"params": {
        "HubName_str": "'"$__hub"'",
        "Name_str": "'"$__user"'"
    } ';

    yq -n '{"jsonrpc": "2.0"} + {"id":"rpc_call_id"} + {"method":"'"$SEmethod"'"} + { eval(strenv(__params)) }' -Po json
}


################################################################################
#
# secli function
#
################################################################################
public::config(){
    private::config(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-f  | --file" "a valid yaml file contains admin credentials";
        printf "%-${HELP_OFFSET}s %s\n" "-t  | --target" "a target of the list of servers";

        exit ${1:-1};
    }


    declare -x rpc_json;
    if (( ${#} == 0 )); then
        if ! [[ -p /dev/stdin ]]; then
            private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
        fi
    fi

    if [[ -p /dev/stdin ]]; then
        rpc_json=$(< /dev/stdin);

        if [[ -z $rpc_json ]]; then
            printf "rpc_json is null/empty\n";
            exit $ERR_EXPR_FAILED;
        fi
    fi

    declare __file='';
    declare __target='';

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::${FUNCNAME/*:/} 0;
            ;;
            -f | --file )
                __file="${2:?Error: a file <name> is needed}";
                shift 2;
            ;;
            -t | --target )
                __target="${2:?Error: a target <name> is needed}";
                shift 2;
            ;;
            * )
                break;
                # printf 'unknown option: %s\n' $1;
                # private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done
    
    : __file="${__file:?Error: a file <name> is needed}";
    : __target="${__target:?Error: a target <name> is needed}";

    private::debug $LINENO '--file' "'${__file}'";
    private::debug $LINENO '--target' "'${__target}'";

    declare -x se_cred;
    se_cred=$(yq ".secli.${__target}" $__file -Po json)
    yq -n '{"se_cred": eval(strenv(se_cred)), "rpc_json": eval(strenv(rpc_json))}' -Po json;
}

public::parse(){
    private::parse(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-t  | --table" "print in table format";
        printf "%-${HELP_OFFSET}s %s\n" "-y  | --yaml" "print in table format";
        printf "%-${HELP_OFFSET}s %s\n" "-m  | --method" "SE server method to parse:";
        printf "%-${HELP_OFFSET}s %s\n" "              " "GetServerInfo";
        printf "%-${HELP_OFFSET}s %s\n" "              " "GetServerStatus";
        printf "%-${HELP_OFFSET}s %s\n" "              " "EnumListener";
        printf "%-${HELP_OFFSET}s %s\n" "              " "CreateUser";
        printf "%-${HELP_OFFSET}s %s\n" "              " "SetUser";
        printf "%-${HELP_OFFSET}s %s\n" "              " "GetUser";
        printf "%-${HELP_OFFSET}s %s\n" "              " "GetUserTable";
        printf "%-${HELP_OFFSET}s %s\n" "              " "DeleteUser";
        printf "%-${HELP_OFFSET}s %s\n" "              " "EnumUser";
        printf "%-${HELP_OFFSET}s %s\n" "              " "EnumUserTable";

        exit ${1:-1};
    }

    declare -x rpc_json;
    if (( ${#} == 0 )); then
        if ! [[ -p /dev/stdin ]]; then
            private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
        fi
    fi

    if [[ -p /dev/stdin ]]; then
        rpc_json=$(< /dev/stdin);

        if (( ${#} == 0 )); then
            declare __json_already_parsed='';
            __json_already_parsed=$(jq -r '.parsed' <<< "$rpc_json");

            if [[ $__json_already_parsed == 'true' ]]; then
                jq '.result' <<< "$rpc_json";
                exit 0;
            fi
        fi
    fi

    declare __method='';
    __method=$(jq -r '.method' <<< "$rpc_json");

    declare __yaml_flag='false';
    declare __json_flag='false';

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::${FUNCNAME/*:/} 0;
            ;;
            -t | --table )
                __method=$(jq -r '.method + "Table"' <<< "$rpc_json");
                shift 1;
            ;;
            -y | --yaml )
                __yaml_flag='true';
                shift 1;
            ;;
            -m | --method )
                __method="${2:?Error: a method <name> is needed}";
                shift 2;
            ;;
            * )
                # break;
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done


    private::debug $LINENO '--method' "'${__method}'";

#    if grep Table$ <<< $__method > /dev/null 2>&1 ; then
#        if [[ -n $__method ]]; then
#            rpc_json=$(jq '.result' <<< "$rpc_json");
#        fi
#    fi


    if [[ $__yaml_flag == 'true' ]]; then
        yq -Po yaml  '.result' <<< "$rpc_json";
        exit 0;
    fi

    : __method="${__method:?Error: a method <name> is needed}";
    case $__method in
        GetServerInfo | GetServerStatus | DeleteUser )
            jq '{ method: "'$__method'" } + { parsed: true } + { result: .result }' <<< "$rpc_json";
        ;;
        EnumListener )
            jq '[ .result.ListenerList[] | { "port": .Ports_u32, "active": .Enables_bool, "error": .Errors_bool } ] |
                { method: "'$__method'" } + { parsed: true } + { result: . }' <<< "$rpc_json";
        ;;
        EnumListenerTable )
            jq -r  '. as $root | $root.result[0] | to_entries | map(.key) | join(" ") as $H | 
                    $H, ($root.result[] | to_entries | map(.value|tostring) | join(" "))' <<< "$rpc_json" | column -t;
        ;;
        GetUser | SetUser | CreateUser )
             jq '.result.HubName_str as $hub |
                 (.result.CreatedTime_dt | sub("(?<time>.*)\\..*Z"; "\(.time)Z")) as $ctime |
                 (.result.ExpireTime_dt | sub("(?<time>.*)\\..*Z"; "\(.time)Z")) as $etime |
                 .result |
                 .Note_utf as $have |
                 (to_entries | map(select(.key | match("byte";"i"))) | map(.value) | add) as $used |
                 { hub: $hub, username: .Name_str, realname: .Realname_utf, access: ."policy:Access_bool",
                 nlogin: .NumLogin_u32, mlogin: ."policy:MultiLogins_u32", policy: .UsePolicy_bool, group: .GroupName_str,  ctime: $ctime, etime: $etime,
                 traffic: {  have: $have | tonumber, used: $used , rest: ($have | tonumber - $used) } } |
                 { method: "'$__method'" } + { parsed: true } + { result: . }' <<< "$rpc_json";
        ;;
        EnumUser )
            jq '[.result.HubName_str as $hub |
                .result.UserList [] |
                (.Expires_dt | sub("(?<time>.*)\\..*Z"; "\(.time)Z")) as $etime |
                (.LastLoginTime_dt | sub("(?<time>.*)\\..*Z"; "\(.time)Z")) as $llogin |
                .Note_utf as $have |
                (to_entries | map(select(.key | match("byte";"i"))) | map(.value) | add) as $used |
                { hub: $hub, username: .Name_str, realname: .Realname_utf, blocked: .DenyAccess_bool, logins: .NumLogin_u32, etime: $etime, llogin: $llogin,
                traffic: {  have: $have | tonumber, used: $used , rest: ($have | tonumber - $used) } }] | 
                { method: "'$__method'" } + { parsed: true } + { result: . }' <<< "$rpc_json";
        ;;
        EnumUserTable )
            jq -r  '. as $root | $root.result[0] | .traffic=null | to_entries | map(.key) | join(" ") as $H | 
                    $H, ($root.result[] | (.traffic | to_entries | map(.value) | map(tostring) | join(" ")) as $traffic | 
                    .traffic=$traffic  | to_entries | map(.value|tostring) | join(" "))' <<< "$rpc_json" | column -t;
        ;;
        GetUserTable | SetUserTable | CreateUserTable )
            jq -r  '. as $root | $root.result | .traffic=null | to_entries | map(.key) | join(" ") as $H | 
                    $H, ($root.result | (.traffic | to_entries | map(.value) | map(tostring) | join(" ")) as $traffic | 
                    .traffic=$traffic  | to_entries | map(.value|tostring|if .=="" then "-" else . end) | join(" "))' <<< "$rpc_json" | column -t;
        ;;
        EnumSession )
            jq '[ .result.HubName_str as $hub |
                .result.SessionList[] |
                ( .Username_str | sub("\\s+"; "-") ) as $username |
                ( .CreatedTime_dt | sub("(?<time>.*)\\..*Z"; "\(.time)Z")) as $create_time |
                ( ( now - ( $create_time | fromdate )) | floor ) as $uptime |
                { username: $username, client_ip: .ClientIP_ip, session_id: .Name_str, hostname: (if (.Hostname_str != "") then .Hostname_str else "-" end), max_tcp: .MaxNumTcp_u32, uptime: $uptime } ] |
                [ to_entries | .[] | .value.index=.key+1 | .value ] | 
                { method: "'$__method'" } + { parsed: true } + { result: . }' <<< "$rpc_json";
        ;;
        EnumSessionTable )
            jq -r  '. as $root | $root.result[0] | to_entries | map(.key) | join(" ") as $H | 
                    $H, ($root.result[] | to_entries | map(.value|tostring) | join(" "))' <<< "$rpc_json" | column -t;
        ;;
        GetSessionStatus )
            jq  '.result as $root |
                $root | 
                ( .TotalRecvSize_u64 + .TotalSendSize_u64 ) as $total |
                { hub: .HubName_str, username: .Username_str, realname: .RealUsername_str, ip: .SessionStatus_ClientIp_ip, 
                  hostname: ."SessionStatus_ClientHostName_str", app: .ClientProductName_str, id: .SessionName_str, 
                  server_ip: .ServerIpAddress_ip, cipher: .CipherName_str, recv: .TotalRecvSize_u64, send: .TotalSendSize_u64, total: $total } | 
                { method: "'$__method'" } + { parsed: true } + { result: . }' <<< "$rpc_json";
        ;;
        GetSessionStatusTable )
            jq -r  '.result as $root | $root | to_entries | map(.key) | join(" ") as $H | $H, ($root | to_entries | map(.value|tostring|sub("[ -]+"; "-"; "g")) | join(" "))' <<< "$rpc_json" | column -t
        ;;
        * )
             printf 'unknown option: %s\n' $__method;
             printf 'please check: parse --help\n';
             exit $ERR_EXPR_FAILED;
        ;;
    esac
}

public::reset(){
    declare -x rpc_json;
    if (( ${#} == 0 )); then
        if ! [[ -p /dev/stdin ]]; then
            private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
        fi
    fi

    if [[ -p /dev/stdin ]]; then
        rpc_json=$(< /dev/stdin);
    fi

    jq <<< "$rpc_json" | yq '.result.*Bytes_u64=0, .result.*Count_u64=0' -Po json
}

public::user(){
    private::user(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-e  | --enum" "enumerate users of a hub";
        printf "%-${HELP_OFFSET}s %s\n" "-g  | --get" "get a user of a hub";
        printf "%-${HELP_OFFSET}s %s\n" "-di | --disable" "disable a user of a hub";
        printf "%-${HELP_OFFSET}s %s\n" "-en | --enable" "enable a user of a hub";
        printf "%-${HELP_OFFSET}s %s\n" "-A  | --add" "add a user to a hub";
        printf "%-${HELP_OFFSET}s %s\n" "-D  | --delete" "delete a user from a hub";

        exit ${1:-1};
    }

    if (( ${#} == 0 )); then
        private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    fi

    declare __se_admin_file='admin.yaml';
    declare __se_server='';
    declare __se_hub='';
    declare __se_hub_user='';

    set +o pipefail;
    declare __se_new_user="$(tr -dc [:lower:][:digit:] < /dev/urandom | head -c 6; echo)";
    declare __se_new_pass="$(tr -dc [:lower:][:digit:] < /dev/urandom | head -c 12; echo)";
    set -o pipefail;
    declare __se_new_realname="user_${__se_new_user}";

    private::enum(){
        secli EnumUser --hub $__se_hub | \
            secli config -f $__se_admin_file -t $__se_server | \
            secli apply | \
            secli parse;

        exit 0;
    }

    private::get(){
        secli GetUser --hub $__se_hub --user $__se_hub_user | \
        secli config -f $__se_admin_file -t $__se_server | \
        secli apply | \
        secli parse;

        exit 0;
    }

    private::user_access(){
        declare -r access_bool="${1?:Error access_book has not been set}";

        secli GetUser --hub $__se_hub --user $__se_hub_user | \
            secli config -f $__se_admin_file -t $__se_server | \
            secli apply | \
            jq '.result."policy:Access_bool"='$access_bool'' | \
            secli SetUser | \
            secli config -f $__se_admin_file -t $__se_server | \
            secli apply | \
            secli parse

        exit 0;
    }

    private::add(){
        declare se_server_address='';
        se_server_address=$(yq ".secli.${__se_server}.address" $__se_admin_file);

        secli CreateUser --hub $__se_hub --user $__se_new_user --pass $__se_new_pass --real $__se_new_realname --note 1 | \
            secli config -f $__se_admin_file -t $__se_server | \
            secli apply | \
            secli parse | \
            jq '. + {credentials: {username: "'$__se_new_user'", password: "'$__se_new_pass'", server: "'$se_server_address'"}}'
        exit 0;
    }

    private::delete(){
        secli DeleteUser --hub $__se_hub --user $__se_hub_user | \
            secli config -f $__se_admin_file -t $__se_server | \
            secli apply
        exit 0;
    }

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::${FUNCNAME/*:/} 0;
            ;;
            -e | --enum )
                __se_server="${2:?Error: a <server> is needed}";
                __se_hub="${3:?Error: a <hub> is needed}";
                private::enum;
            ;;
            -g | --get )
                __se_server="${2:?Error: a <server> is needed}";
                __se_hub="${3:?Error: a <hub> is needed}";
                __se_hub_user="${4:?Error: a <username> is needed}";
                private::get;
            ;;
            -di | --disable )
                __se_server="${2:?Error: a <server> is needed}";
                __se_hub="${3:?Error: a <hub> is needed}";
                __se_hub_user="${4:?Error: a <username> is needed}";
                private::user_access false;
            ;;
            -en | --enable )
                __se_server="${2:?Error: a <server> is needed}";
                __se_hub="${3:?Error: a <hub> is needed}";
                __se_hub_user="${4:?Error: a <username> is needed}";
                private::user_access true;
            ;;
            -A | --add )
                __se_server="${2:?Error: a <server> is needed}";
                __se_hub="${3:?Error: a <hub> is needed}";

                __se_new_user="${4:-$__se_new_user}";
                __se_new_pass="${5:-$__se_new_pass}";
                __se_new_realname="${6:-user_$__se_new_user}";
                private::add;
            ;;
            -D | --delete )
                __se_server="${2:?Error: a <server> is needed}";
                __se_hub="${3:?Error: a <hub> is needed}";
                __se_hub_user="${4:?Error: a <username> is needed}";
                private::delete;
            ;;
            * )
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done

    if ! [[ -f $__se_admin_file ]]; then
        printf "SE server admin file: '%s' not found\n" $__se_admin_file;
        exit $ERR_EXPR_FAILED;
    fi

    : __se_server="${__se_server:?Error: __se_server has not been set}";
    : __se_hub="${__se_hub:?Error: __se_hub has not been set}";

    private::debug $LINENO '__se_admin_file:' "'${__se_admin_file}'";
    private::debug $LINENO '__se_server:' "'${__se_server}'";
    private::debug $LINENO '__se_hub:' "'${__se_hub}'";
}


public::session(){
    private::session(){
        printf "${FUNCNAME/*:/}\n\n";
        printf "%-${HELP_OFFSET}s %s\n" "-h  | --help" "show this help";
        printf "%-${HELP_OFFSET}s %s\n" "-e  | --enum" "enumerate sessions of a hub";
        printf "%-${HELP_OFFSET}s %s\n" "-g  | --get" "get status of a user in a session (session-id is needed)";
        printf "%-${HELP_OFFSET}s %s\n" "-D  | --disconnect" "disconnect a user of a session (remove it)";

        exit ${1:-1};
    }

    if (( ${#} == 0 )); then
        private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    fi

    declare __se_admin_file='admin.yaml';
    declare __se_server='';
    declare __se_hub='';
    declare __se_user_session_id='';

    if ! [[ -f $__se_admin_file ]]; then
        printf "SE server admin file: '%s' not found\n" $__se_admin_file;
        exit $ERR_EXPR_FAILED;
    fi


    private::enum(){
        secli EnumSession --hub $__se_hub | \
            secli config -f $__se_admin_file -t $__se_server | \
            secli apply | \
            secli parse;

        exit 0;
    }

    private::get(){
        secli GetSessionStatus --hub $__se_hub --user $__se_user_session_id| \
        secli config -f $__se_admin_file -t $__se_server | \
        secli apply | \
        secli parse;

        exit 0;
    }

    private::delete(){
        secli DeleteUser --hub $__se_hub --user $__se_user_session_id| \
            secli config -f $__se_admin_file -t $__se_server | \
            secli apply
        exit 0;
    }

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::${FUNCNAME/*:/} 0;
            ;;
            -e | --enum )
                __se_server="${2:?Error: a <server> is needed}";
                __se_hub="${3:?Error: a <hub> is needed}";
                private::enum;
            ;;
            -g | --get )
                __se_server="${2:?Error: a <server> is needed}";
                __se_hub="${3:?Error: a <hub> is needed}";
                __se_user_session_id="${4:?Error: a <user session id> is needed}";
                private::get;
            ;;
            -D | --disconnect )
                __se_server="${2:?Error: a <server> is needed}";
                __se_hub="${3:?Error: a <hub> is needed}";
                __se_user_session_id="${4:?Error: a <user session id> is needed}";
                private::delete;
            ;;
            * )
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done
}

################################################################################
#
# main function
#
################################################################################
private::example(){
    echo example for $CLI_NAME;
    echo not implemented yet
}

private::cli_install(){
    if which $CLI_NAME > /dev/null 2>&1 ; then
        read -p "Already $CLI_NAME has been installed, want to overwrite [y/n]? " user_choice;
        case $user_choice in
            y )
                sudo install $CLI_NAME -t $CLI_INSTALL_PATH/
                which $CLI_NAME;
            ;;
            * )
                printf "installing $0 cancelled\n";
                exit $EXIT_NO_ERR;

            ;;
        esac
    else
        sudo install $CLI_NAME -t $CLI_INSTALL_PATH/
        which $CLI_NAME;
    fi

    exit $?;
}

private::cli_version(){
    printf "%s %s\n" $CLI_NAME $CLI_VERSION;

    exit $EXIT_NO_ERR;
}

private::debug(){
    if [[ $SCRIPT_DEBUG_FLAG == true ]]; then
        private::warn "script($1)"  "${@:2}";
    fi
}

private::debug_x(){
    set -x;
}

private::main_help(){
    printf "$ANSISHELL_HEADER";

    printf "\n\nusage:\n";
    printf "$CLI_NAME [--options]\n";
    printf "$CLI_NAME command [--options]\n";
    printf "$CLI_NAME [--options] command [--options]\n";

    printf "\noptions:\n";
    printf "%-${HELP_OFFSET}s %s\n" '-h  | --help' 'show this help menu';
    printf "%-${HELP_OFFSET}s %s\n" '-v  | --version' 'show version';
    printf "%-${HELP_OFFSET}s %s\n" '-i  | --install' 'install this CLI';
    printf "%-${HELP_OFFSET}s %s\n" '-e  | --example' 'show some examples';
    printf "%-${HELP_OFFSET}s %s\n" '-d  | --debug' 'enable debugging (script level)';
    printf "%-${HELP_OFFSET}s %s\n" '-D  | --debug-x' 'enable bash debugging (bash level)';

    printf "\nsecli commands:\n";
    printf "%-${HELP_OFFSET}s %s\n" 'help' 'show help menu';
    printf "%-${HELP_OFFSET}s %s\n" 'user' 'a user functions';
    printf "%-${HELP_OFFSET}s %s\n" 'session' 'a session functions';
    printf "%-${HELP_OFFSET}s %s\n" 'config' 'read SE server admin yaml file';
    printf "%-${HELP_OFFSET}s %s\n" 'apply' 'send RPC-JSON to SE server';
    printf "%-${HELP_OFFSET}s %s\n" 'parse' 'parse SE server response';
    printf "%-${HELP_OFFSET}s %s\n" 'reset' 'reset Bytes and Counts';
    
    printf "\nRPC API commands:\n";
    printf "%-${HELP_OFFSET}s %s\n" 'Test' 'Test RPC function';

    printf "\n";
    printf "%-${HELP_OFFSET}s %s\n" 'GetServerInfo' 'Get server information';
    printf "%-${HELP_OFFSET}s %s\n" 'GetServerStatus' 'Get Current Server Status';

    printf "\n";
    printf "%-${HELP_OFFSET}s %s\n" 'CreateListener' 'Create New TCP Listener';
    printf "%-${HELP_OFFSET}s %s\n" 'EnumListener' 'Get List of TCP Listeners';
    printf "%-${HELP_OFFSET}s %s\n" 'DeleteListener' 'Delete TCP Listener';
    printf "%-${HELP_OFFSET}s %s\n" 'EnableListener' 'Enable / Disable TCP Listener';

    printf "\n";
    printf "%-${HELP_OFFSET}s %s\n" 'CreateUser' 'Create a user';
    printf "%-${HELP_OFFSET}s %s\n" 'SetUser' 'Change User Settings';
    printf "%-${HELP_OFFSET}s %s\n" 'GetUser' 'Get User Settings';
    printf "%-${HELP_OFFSET}s %s\n" 'DeleteUser' 'Delete a user';
    printf "%-${HELP_OFFSET}s %s\n" 'EnumUser' 'Get List of Users';

    printf "\n";
    printf "%-${HELP_OFFSET}s %s\n" 'EnumSession' 'Get List of Connected VPN Sessions';
    printf "%-${HELP_OFFSET}s %s\n" 'GetSessionStatus' 'Get Session Status';
    printf "%-${HELP_OFFSET}s %s\n" 'DeleteSession' 'Disconnect Session';

    exit ${1:-1};
}

private::parse_options(){
    if (( ${#} == 0 )); then
        private::main_help 0;
    fi

    case $1 in
        -h | --help )
            private::main_help 0;
        ;;
        -d | --debug )
            SCRIPT_DEBUG_FLAG=true
            shift;
        ;;
        -D | --debug-x )
            private::debug_x;
            shift;
        ;;
        -e | --example )
            private::example;
            shift;
        ;;
        -v | --version )
            private::cli_version;
            shift;
        ;;
        -i | --install )
            private::cli_install;
        ;;
    esac

    if (( ${#} != 0 )); then
        private::debug $LINENO continue-main: "'$@'";
        private::main "$@";
    fi
}


private::main(){
    if (( ${#} == 0 )); then
        private::main_help 0;
    fi

    case ${1} in
        config | apply | parse | reset | user | session | Test | GetServerInfo | GetServerStatus | CreateListener | EnumListener | DeleteListener | EnableListener | CreateUser | SetUser | GetUser | DeleteUser | EnumUser | EnumSession | GetSessionStatus )
            private::debug $LINENO 'command:' "'${1}'";
            private::debug $LINENO 'command-options:' "'${@:2}'";
            public::${1} "${@:2}";
        ;;
        * )
            private::parse_options "$@";
        ;;
    esac
}

private::main "$@";
