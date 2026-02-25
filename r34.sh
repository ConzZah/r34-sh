#!/usr/bin/env bash

### r34.sh // ConzZah // 2/25/26 5:05 PM ###

init () {
kitten icat --clear; clear
search=""; action=""; pid="0" ## <-- NOTE: PID STARTS AT 0 AND USUALLY INCREMENTS IN STEPS OF 42
deps="grep curl kitten tput sed"
for dep in $deps; do
! command -v "$dep" >/dev/null && \
printf '%s\n' "--> ERROR: $dep MISSING." && exit 1 
done

! kitten icat --detect-support &>/dev/null && \
printf '%s\n' '--> ERROR: TERMINAL NOT COMPATIBLE WITH KITTY GRAPHICS PROTOCOL' && exit 1 || 
printf '%s\n' '--> COMPATIBLE TERMINAL FOUND' >/dev/null

printf  '%s\n\n' " == r34.sh // ConzZah // 2026 =="
kitty icat 'https://rule34.xxx/images/headerru.png?v2'
[ -z "$1" ] && printf '\n%s' "SEARCH --> " && read -r search
[ -n "$1" ] && search="$1" && shift
main
}


main () {
fetch_page
until [ -n "$x" ]; do
read -r -s -n1 action
### THUMBNAIL ACTIONS ###
[ "$action" = "d" ] && { ## <-- next thumbnail
[ "$tc" = "$max_tc" ] && [ "$max_tc" = '42' ] && action="w" || \
[ "$tc" -ne "$max_tc" ] && tc=$((tc + 1)) && fetch_thumb ;}
 
[ "$action" = "a" ] && { ## <-- previous thumbnail
[ "$tc" = "1" ] && [ "$pid" -gt "0" ] && action="s" || \
[ "$tc" -ne "1" ] && tc=$((tc - 1)) && fetch_thumb ;}

### PAGE ACTIONS ###
[ "$action" = "w" ] && [ "$max_tc" = "42" ] && pid=$((pid + max_tc)) && fetch_page ### <-- page up
[ "$action" = "s" ] && [ "$pid" -ne "0" ] && pid=$((pid - max_tc)) && fetch_page ## <-- page down

### DOWNLOAD ###
[ "$action" = "c" ] && fetch_fullsize && download

### FULLSIZE ###
[ "$action" = "f" ] && fetch_fullsize

### GO BACK TO SEARCH ###
[ "$action" = "q" ] && init

### no-op + cooldown for when nothing matched ### 
[ "$action" = "" ] && sleep 0.3 && :

action=""
done
}


fetch_page () {
tc="1" ## <-- reset thumbnail-counter to 1 whenever we call this function
ua="Mozilla/5.0 (X11; Linux x86_64; rv:147.0) Gecko/20100101 Firefox/147.0"
curl -s "https://rule34.xxx/index.php?page=post&s=list&tags=${search}&pid=${pid}" \
  --compressed \
  -H "User-Agent: $ua" \
  -H 'Accept-Language: en-US,en;q=0.9' \
  -H 'Referer: https://rule34.xxx/' \
  -H 'DNT: 1' \
  -H 'Sec-GPC: 1' \
  -H 'Connection: keep-alive' \
  -H 'Upgrade-Insecure-Requests: 1' \
  -H 'Sec-Fetch-Dest: document' \
  -H 'Sec-Fetch-Mode: navigate' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-User: ?1' \
  -H 'Priority: u=0, i' \
  -H 'Pragma: no-cache' \
  -H 'Cache-Control: no-cache' \
  -H 'TE: trailers' > '.html' || exit 1

## get the thumbnails 
grep -o '.*thumbnails.*' '.html'| cut -d '"' -f 2 > '.thumbs'

## if $max_tc is 0 then we have no results
max_tc="$(wc -l '.thumbs'| cut -d ' ' -f 1)"
[ "$max_tc" = "0" ] && printf '%s' '--> NOBODY HERE BUT US CHICKENS...' && sleep 1 && init 
fetch_thumb
}


fetch_thumb () {
kitten icat --clear; clear
printf "%s\n\n" "PAGE-ID: $pid // PAGE-ITEM: ${tc}/${max_tc}"
curl -s#  "$(sed -n "$tc p" '.thumbs')" \
  -H "User-Agent: $ua" \
  -H 'Accept: image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5' \
  -H 'Referer: https://rule34.xxx/' --output -| kitten icat --align left || exit 1
  show_controls
}


fetch_fullsize () {
url=""; id=""
kitten icat --clear; clear
id="$(sed -n "$tc p" '.thumbs'| cut -d '?' -f 2)"
url="$(curl -s "https://rule34.xxx/index.php?page=post&s=view&id=$id" \
  --compressed \
  -H "User-Agent: $ua" \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
  -H 'Accept-Language: en-US,en;q=0.9' \
  -H 'Accept-Encoding: gzip, deflate, br, zstd' \
  -H 'DNT: 1' \
  -H 'Sec-GPC: 1' \
  -H 'Alt-Used: rule34.xxx' \
  -H 'Connection: keep-alive' \
  -H 'Upgrade-Insecure-Requests: 1' \
  -H 'Sec-Fetch-Dest: document' \
  -H 'Sec-Fetch-Mode: navigate' \
  -H 'Sec-Fetch-Site: none' \
  -H 'Sec-Fetch-User: ?1' \
  -H 'Priority: u=0, i' \
  -H 'Pragma: no-cache' \
  -H 'Cache-Control: no-cache' \
  -H 'TE: trailers'| grep -o -m1 "https://.*rule34.xxx.*$id"| cut -d '"' -f 2)"


## if $action != c, and the file we're trying to view is a video, politely tell the user & return
[ "$action" != "c" ] && grep -q '.mp4' <<< "$url" && { printf '%s\n' '--> SIR, THIS IS A VIDEO.'; sleep 0.7; fetch_thumb; return ;}

## if $action = c, we're downloading the image, 
## and skipping the fullscreen display by returning
[ "$action" = "c" ] && return

curl -s "$url" \
  -H "User-Agent: $ua" \
  -H 'Accept: image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5' \
  -H 'Accept-Language: en-US,en;q=0.9' \
  -H 'Accept-Encoding: gzip, deflate, br, zstd' \
  -H 'DNT: 1' \
  -H 'Sec-GPC: 1' \
  -H 'Alt-Used: wimg.rule34.xxx' \
  -H 'Connection: keep-alive' \
  -H 'Referer: https://rule34.xxx/' \
  -H 'Sec-Fetch-Dest: image' \
  -H 'Sec-Fetch-Mode: no-cors' \
  -H 'Sec-Fetch-Site: same-site' \
  -H 'Priority: u=5, i' \
  -H 'Pragma: no-cache' \
  -H 'Cache-Control: no-cache' \
  -H 'TE: trailers' --output -| \
kitten icat -n --align left --use-window-size "$(tput cols),$(tput lines),$(kitten icat --print-window-size| sed 's#x#,#')" || exit 1
}


download () { printf '%s\n' "--> DOWNLOADING: $url"; curl -O# -H "User-Agent: $ua" "$url"; sleep 0.7; fetch_thumb ;}

show_controls () { printf '\n[c] = DOWNLOAD [f] = FULL-SIZE\n[w] = PAGE UP  [s] = PAGE DOWN\n[a] = PREV     [d] = NEXT\n\n' ;}

cleanup() { rm -f '.html' '.thumbs' &>/dev/null; exit ;}

trap cleanup EXIT INT QUIT TERM

##### LAUNCH #####
init "$1"
