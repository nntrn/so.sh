#!/usr/bin/env bash

URL="$1"
ANSWER_PATH=${URL##*\/a\/}
ANSWER_ID=${ANSWER_PATH%%/*}
ANSWER_SITE="$(echo "$URL" | sed 's,.*://\(.*\).com.*,\1,g')"

[[ -f $HOME/.sorc ]] && source $HOME/.sorc

DEFAULT_SO_FILTER='!Fc6H2WoBkYbO3_Vk)v*aMCyxFm'
DEFAULT_SO_KEY='U4DMV*8nvpm3EOpvf69Rxw(('
DEFAULT_SO_OUT=$HOME/so

SO_FILTER="${SO_FILTER:-$DEFAULT_SO_FILTER}"
SO_KEY="${SO_KEY:-$DEFAULT_SO_KEY}"
SO_OUT=${SO_OUT:-$DEFAULT_SO_OUT}
SO_FILES_DIR=$SO_OUT/files
SO_CACHE_DIR=$SO_OUT/.cache

API_ANSWER_URL="https://api.stackexchange.com/2.3/answers/${ANSWER_ID}?site=${ANSWER_SITE}&filter=${SO_FILTER}&key=${SO_KEY}"
API_URL_CHKSUM=$(echo "$API_ANSWER_URL" | md5sum | awk '{print $1}')
API_CACHE_JSON=$SO_CACHE_DIR/${API_URL_CHKSUM}.json

MARKDOWN_FILE=$SO_FILES_DIR/${ANSWER_ID}.md

mkdir -p $SO_OUT/{files,.cache}

_var() {
  echo -e "\e[0;37m${1}=\e[0;33m${2}\e[0m" 3>&2 2>&1 >&3 3>&-
}

# remove empty file
[[ -f $API_CACHE_JSON ]] && [[ ! -s $API_CACHE_JSON ]] && rm $API_CACHE_JSON

if [[ ! -f $API_CACHE_JSON ]]; then
  curl -s -o $API_CACHE_JSON "$API_ANSWER_URL" --fail --compressed
fi

JQ_CMD='
.items[] | [
  "---",
  "title: \(.title)",
  "url: \(.share_link)",
  "---",
  "",
  .body_markdown,
  "",
  "---",
  "answered on \(.creation_date | strftime("%b %e, %Y at %R")) by [\(.owner.display_name)](\(.owner.link))",
  ""
] | join("\n") | gsub("\r";"")
'

# jq -r "$JQ_CMD" $API_CACHE_JSON >$MARKDOWN_FILE
# sed -i 's/&nbsp;/ /g; s/&amp;/\&/g; s/&lt;/\</g; s/&gt;/\>/g; s/&#\(x27\|39\);/\'"'"'/g; s/&\(ldquo\|rdquo\|quot\);/\"/g;' $MARKDOWN_FILE

jq -r "$JQ_CMD" $API_CACHE_JSON |
  sed 's/&nbsp;/ /g; s/&amp;/\&/g; s/&lt;/\</g; s/&gt;/\>/g; s/&#\(x27\|39\);/\'"'"'/g; s/&\(ldquo\|rdquo\|quot\);/\"/g;' |
  cat -s |
  tee $MARKDOWN_FILE

_var API_CACHE_JSON "$API_CACHE_JSON"
_var API_ANSWER_URL "'${API_ANSWER_URL%&key=*}'"
_var MARKDOWN_FILE "$MARKDOWN_FILE"
