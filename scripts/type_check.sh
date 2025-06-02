#!/usr/bin/env bash

PLUGIN="symbols"

LOGS_DIR=luals/logs
META_DIR=luals/meta
TYPE_CHECK_LOGS_FILE=${LOGS_DIR}/check.json

mkdir -p ${LOGS_DIR}
mkdir -p ${META_DIR}
./deps/lua-language-server/bin/lua-language-server \
    --check="lua/${PLUGIN}" \
    --logpath="${LOGS_DIR}" \
    --checklevel=Hint \
    --metapath="${META_DIR}" \
    --configpath=../../.luarc.json

USE_JQ=false
if [ -x "$(command -v jq)" ]; then
  USE_JQ=true
fi

JQ_QUERY=$(cat <<'END'
    def severities_map:
        { "1": "ERROR", "2": "WARNING", "3": "INFO", "4": "HINT" };

    [
        . | to_entries | .[] |
        { file: (.key | "./lua/${PLUGIN}" + split("lua/${PLUGIN}")[1]) } *
        ( .value | .[] |
            {
                code: .code,
                message: .message,
                line: (.range.start.line + 1),
                severity: ( .severity | tostring | severities_map[.] )
            }
        )
    ] | sort_by(.file, .line, .severity)
    | .[] | "[" + .severity + "] " + .file + ":" + (.line | tostring) + " (" + .code + ") " + .message
END
)

LINES=$( wc -l <"${TYPE_CHECK_LOGS_FILE}" )
if (( LINES > 0 )); then
    if [ "$USE_JQ" = true ]; then
        jq -r "${JQ_QUERY}" ${TYPE_CHECK_LOGS_FILE}
    fi
    exit 1
fi
