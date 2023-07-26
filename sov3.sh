#!/bin/bash

SO_ROOT=$HOME/so/questions
SO_CACHE=$HOME/.cache/so

[[ ! -d $SO_ROOT ]] && mkdir -p $SO_ROOT

SO_KEY='U4DMV*8nvpm3EOpvf69Rxw(('
SO_PAGE_SIZE=100
SO_TAGGED=jq
SO_PAGE=1

SO_QUESTIONS_URL='https://api.stackexchange.com/2.3/questions?order=desc&sort=votes&site=stackoverflow'
SO_QUESTIONS_FILTER='!9B4loAbXj(Oc-QDOl9-Tqycvt24fKpTE*y5VaiO9Sd-U2n3*ypvtFV1'

# choices: hourly, daily, weekly, monthly, yearly, [null]
# leave blank if no update is needed

SO_CACHE_UPDATE_FREQ=

_update_freq() {
  local TIMEOUT_PREFIX=
  case "${1,,}" in
  hourly) TIMEOUT_PREFIX='%FH%H' ;;
  daily) TIMEOUT_PREFIX='%F' ;;
  weekly) TIMEOUT_PREFIX='%YW%W' ;;
  monthly) TIMEOUT_PREFIX='%Y%b' ;;
  yearly) TIMEOUT_PREFIX='%Y' ;;
  esac

  [[ -n $TIMEOUT_PREFIX ]] && date +$TIMEOUT_PREFIX
}

CACHE_PREFIX=$(_update_freq $SO_CACHE_UPDATE_FREQ)

_cache_file() {
  local URL="$1"
  local OUTPUT_DIR=$SO_CACHE

  CHECKSUM=$(echo "${URL}" | md5sum | awk '{print $1}')

  [[ ${#FUNCNAME[@]} -gt 1 ]] && OUTPUT_DIR="${SO_CACHE}/${FUNCNAME[0]}"
  [[ ! -d $OUTPUT_DIR ]] && mkdir -p $OUTPUT_DIR
  CACHE_FILE="${OUTPUT_DIR}/${CHECKSUM}${CACHE_PREFIX}.json"
  if [[ ! -f $CACHE_FILE ]]; then
    HTTP_CODE=$(curl -s --compressed -w '%{http_code}' -o "$CACHE_FILE" "$URL" --fail)
    if [[ $HTTP_CODE -eq 200 ]]; then
      [[ -n $CACHE_PREFIX ]] && cat $CACHE_FILE >${OUTPUT_DIR}/${CHECKSUM}.json
      echo "$(date +'%F%X') ${CHECKSUM} ${CACHE_FILE}" >>$SO_CACHE/files.1
      echo "${CHECKSUM} ${URL}" >>$SO_CACHE/index.1
    fi
  fi
  if [[ -f $CACHE_FILE ]] && [[ -s $CACHE_FILE ]]; then
    LAST_CACHE_FILE=$CACHE_FILE
  else
    CACHED_FILES=($(ls -t1 $OUTPUT_DIR/$CHECKSUM* 2>/dev/null))
    LAST_CACHE_FILE=${CACHED_FILES[0]}
  fi
  export LAST_CACHE_FILE
}

so_questions() {
  local CURL_URL="${SO_QUESTIONS_URL}&tagged=${SO_TAGGED}&page_size=${SO_PAGE_SIZE}&key=${SO_KEY}&filter=${SO_QUESTIONS_FILTER}"
  local SO_OUTPUT_FILE=$SO_ROOT/questions-${SO_TAGGED}-${SO_PAGE}.md

  _cache_file "$CURL_URL"

  [[ -f $LAST_CACHE_FILE ]] && jq -r '.items 
    | map(.answers) 
    | flatten 
    | map( select(.score > 5 or .is_accepted) 
    | [ "\(.title)", 
        "=" * (.title|length),
        "",
        (.body_markdown | gsub("\r";"")),
        "",
        "---",
        "\(.score) Upvotes",
        "\(.creation_date | strftime("answered on %b %e, %Y at %R")) by [\(.owner.display_name)](\(.owner.link))",
        "",
        .share_link,
        "", 
        "#"* 90
      ] | join("\n") | gsub("[\\n]{2,}";"\n\n")) 
    | join("\n\n")' $LAST_CACHE_FILE |
    python -c "import html, sys; print(html.unescape(sys.stdin.read()))" |
    tee $SO_OUTPUT_FILE

  echo -e "File saved to: \e[38;5;38m${SO_OUTPUT_FILE}\e[0m"

}
