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
    declare payload='';
    SEserver[addr]=$(yq '.se_cred.address' <<< "$se_data");
    SEserver[port]=$(yq '.se_cred.port' <<< "$se_data");
    SEserver[pass]=$(yq '.se_cred.password' <<< "$se_data");
    curl_data=$(yq '.rpc_json' <<< "$se_data");

    case ${__format} in
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
        printf "%-${HELP_OFFSET}s %s\n" "-a  | --auth-type" "type for authentication [0-5], default=1";
        printf "%-${HELP_OFFSET}s %s\n" "-P  | --p-rule" "enable policy rules for a user [=false|true]";
        printf "%-${HELP_OFFSET}s %s\n" "-Pa | --p-access" "policy: access for a user [=true|false]";
        printf "%-${HELP_OFFSET}s %s\n" "-Pf | --p-fix-pass" "policy: fix password for a user [=true|false]";
        printf "%-${HELP_OFFSET}s %s\n" "-Pm | --p-mulit-login" "policy: multiple login  for a user [=1]";

        exit ${1:-1};
    }

    if (( ${#} == 0 )); then
        private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    fi

    declare __hub='';
    declare __user_name='';
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
            -Pf | --p-fix-pass )
                __policy_fix_pass="${2:?Error: a <true/false> is needed}";
                shift 2;
            ;;
            -Pm | --p-mulit-login )
                __policy_multi_login="${2:?Error: a <true/false> is needed}";
                shift 2;
            ;;

            * )
                printf 'unknown option: %s\n' $1;
                private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
            ;;
        esac
    done
    
    : __hub="${__hub:?Error: a hub <name> is needed}";
    : __user_name="${__user_name:?Error: a user <name> is needed}";
    : __user_pass="${__user_pass:?Error: a user <password> is needed}";

    private::debug $LINENO '--hub' "'${__hub}'";
    private::debug $LINENO '--user' "'${__user_name}'";
    private::debug $LINENO '--pass' "'${__user_pass}'";
    private::debug $LINENO '--real' "'${__real_name}'";
    private::debug $LINENO '--note' "'${__user_note}'";
    private::debug $LINENO '--p-rule' "'${__policy_rule}'";
    private::debug $LINENO '--p-access' "'${__policy_access}'";
    private::debug $LINENO '--p-fix-pass' "'${__policy_fix_pass}'";
    private::debug $LINENO '--p-mulit-login' "'${__policy_multi_login}'";

    declare -x __params=' "params": {
        "HubName_str": "'"${__hub}"'",
        "Name_str": "'"${__user_name}"'",
        "Realname_utf": "'"${__real_name}"'",
        "Note_utf": "'"${__user_note}"'",
        "ExpireTime_dt": "",
        "AuthType_u32": '${__auth_type}',
        "Auth_Password_str": "'"${__user_pass}"'",
        "UsePolicy_bool": '${__policy_rule}',
        "policy:Access_bool": '${__policy_access}',
        "policy:MaxConnection_u32": 32,
        "policy:TimeOut_u32": 20,
        "policy:FixPassword_bool": true,
        "policy:MultiLogins_u32": '${__policy_multi_login}'
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

    declare quary_result='';
    if (( ${#} == 0 )); then
        private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
    fi

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
                quary_result=$(yq '.result.HubName_str="'"${__hub}"'"  ' -Po json <<< "$quary_result");
            ;;
            -p | --user )
                __user_name="${2:?Error: a user <name> is needed}";
                shift 2;
                quary_result=$(yq '.result.Name_str="'"${__user_name}"'"  ' -Po json <<< "$quary_result");
            ;;
            -p | --pass )
                __user_pass="${2:?Error: a password is needed}";
                shift 2;
                quary_result=$(yq '.result.Auth_Password_str="'"${__real_name}"'"  ' -Po json <<< "$quary_result");
            ;;
            -r | --real )
                __real_name="${2:?Error: a full <name> is needed}";
                shift 2;
                quary_result=$(yq '.result.Realname_utf="'"${__real_name}"'"  ' -Po json <<< "$quary_result");
            ;;
            -n | --note )
                __user_note="${2:?Error: a note is needed}";
                shift 2;
                quary_result=$(yq '.result.Note_utf="'"${__user_note}"'"  ' -Po json <<< "$quary_result");
            ;;
            -a | --auth-type )
                __auth_type="${2:?Error: a <number> is needed [0-5}";
                shift 2;
                quary_result=$(yq '.result.AuthType_u32='${__auth_type}'  ' -Po json <<< "$quary_result");
            ;;
            -P | --p-rule )
                __policy_rule="${2:?Error: a <true/false> is needed}";
                shift 2;
                quary_result=$(yq '.result.UsePolicy_bool='${__policy_rule}'  ' -Po json <<< "$quary_result");
            ;;
            -Pa | --p-access )
                __policy_access="${2:?Error: a <true/false> is needed}";
                shift 2;
                quary_result=$(yq '.result."policy:Access_bool"='${__policy_access}'  ' -Po json <<< "$quary_result");
            ;;
            -Pf | --p-fix-pass )
                __policy_fix_pass="${2:?Error: a <true/false> is needed}";
                shift 2;
                quary_result=$(yq '.result."policy:FixPassword_bool"='${__policy_fix_pass}'  ' -Po json <<< "$quary_result");
            ;;
            -Pm | --p-mulit-login )
                __policy_multi_login="${2:?Error: a <true/false> is needed}";
                shift 2;
                quary_result=$(yq '.result."policy:MultiLogins_u32"='${__policy_multi_login}' ' -Po json <<< "$quary_result");
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

    declare -x __params="$(yq '.result' <<< $quary_result | jq '.')";
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
        printf "%-${HELP_OFFSET}s %s\n" "-m  | --method" "a valid yaml file contains admin credentials";
        printf "%-${HELP_OFFSET}s %s\n" "              " "GetServerInfo";
        printf "%-${HELP_OFFSET}s %s\n" "              " "GetServerStatus";
        printf "%-${HELP_OFFSET}s %s\n" "              " "EnumListener";
        printf "%-${HELP_OFFSET}s %s\n" "              " "CreateUser";
        printf "%-${HELP_OFFSET}s %s\n" "              " "SetUser";
        printf "%-${HELP_OFFSET}s %s\n" "              " "GetUser";
        printf "%-${HELP_OFFSET}s %s\n" "              " "DeleteUser";
        printf "%-${HELP_OFFSET}s %s\n" "              " "EnumUser";

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
    fi

    declare __method='';

    while (( ${#} > 0 )); do
        case ${1} in
            -h | --help )
                private::${FUNCNAME/*:/} 0;
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

    : __method="${__method:?Error: a method <name> is needed}";

    private::debug $LINENO '--method' "'${__method}'";

   case $__method in
       GetServerInfo | GetServerStatus | CreateUser | SetUser | GetUser | DeleteUser )
           echo "$rpc_json" | jq | yq -Po yaml '.result  | .[] |= select(tag == "!!str") |= sub("\s+", "-")' | column -t
       ;;
       EnumListener )
           echo "$rpc_json" | jq | yq -Po yaml '.result.ListenerList[] | [  { "port": .Ports_u32, "active": .Enables_bool, "error": .Errors_bool } ]'
       ;;
       EnumUser )
           # found bug on yq v4.21 for Compare Operators
           # echo "$rpc_json" | yq  '.result.UserList [] | [ { "name": .Name_str, "blocked": .DenyAccess_bool, "real_name": .Realname_utf, "logins": .NumLogin_u32, "last_login": .LastLoginTime_dt, "traffic_max": .Note_utf , "traffic_used": [ .*Bytes* ] | map(. as $item ireduce (0; . + $item)) | .[] } ] | .[].traffic_max tag= "!!int" | ' -Po yaml

           # did not have that bug using yq v4.31 for Compare Operators
           echo "$rpc_json" | yq  '.result.HubName_str as $hub | .result.UserList [] | [ { "hub": $hub, "name": .Name_str, "logins": .NumLogin_u32,"blocked": .DenyAccess_bool, "real_name": .Realname_utf, "last_login": .LastLoginTime_dt,    "traffic":  { "have": .Note_utf, "used": [ .*Bytes* ] | map(. as $item ireduce (0; . + $item)) | .[] } } ] | .[].traffic.have tag= "!!int" | .[].traffic.rest = .[].traffic.have - .[].traffic.used '  -Po yaml
       ;;
       * )
            printf 'unknown option: %s\n' $__method;
            private::${FUNCNAME/*:/} $ERR_EXPR_FAILED;
       ;;
   esac
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
    printf "%-${HELP_OFFSET}s %s\n" 'config' 'read SE server admin yaml file';
    printf "%-${HELP_OFFSET}s %s\n" 'apply' 'send RPC-JSON to SE server';
    printf "%-${HELP_OFFSET}s %s\n" 'parse' 'parse SE server response';
    
    printf "\nRPC API commands:\n";
    printf "%-${HELP_OFFSET}s %s\n" 'Test' 'Test RPC function';

    printf "%-${HELP_OFFSET}s %s\n" 'GetServerInfo' 'Get server information';
    printf "%-${HELP_OFFSET}s %s\n" 'GetServerStatus' 'Get Current Server Status';

    printf "%-${HELP_OFFSET}s %s\n" 'CreateListener' 'Create New TCP Listener';
    printf "%-${HELP_OFFSET}s %s\n" 'EnumListener' 'Get List of TCP Listeners';
    printf "%-${HELP_OFFSET}s %s\n" 'DeleteListener' 'Delete TCP Listener';
    printf "%-${HELP_OFFSET}s %s\n" 'EnableListener' 'Enable / Disable TCP Listener';

    printf "%-${HELP_OFFSET}s %s\n" 'CreateUser' 'Create a user';
    printf "%-${HELP_OFFSET}s %s\n" 'SetUser' 'Change User Settings';
    printf "%-${HELP_OFFSET}s %s\n" 'GetUser' 'Get User Settings';
    printf "%-${HELP_OFFSET}s %s\n" 'DeleteUser' 'Delete a user';
    printf "%-${HELP_OFFSET}s %s\n" 'EnumUser' 'Get List of Users';

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
        config | apply | parse | Test | GetServerInfo | GetServerStatus | CreateListener | EnumListener | DeleteListener | EnableListener | CreateUser | SetUser | GetUser | DeleteUser | EnumUser )
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
