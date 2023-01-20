#!/bin/bash

set -euo pipefail

declare _hub="${1:?hub name}";
declare _target="${2:?target name}"

./secli EnumUser --hub $_hub | \
    ./secli config -f admin.yaml -t $_target | \
    ./secli apply | \
    ./secli parse -m EnumUser | \
    jq '[ .[] | select(.blocked==true) ]' 




