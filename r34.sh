#!/usr/bin/env bash

### r34.sh // ConzZah // 3/4/26 4:55 AM ###

init () {
clear
image_header='Accept: image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5'
ua="Mozilla/5.0 (X11; Linux x86_64; rv:147.0) Gecko/20100101 Firefox/147.0"
kittypath="$HOME/.local/kitty.app"; kitten="kitten"; kitty="kitty"
search=""; page_counter="1"; pid="0" ## <-- NOTE: PID STARTS AT 0 AND USUALLY INCREMENTS IN STEPS OF 42
[ "$action" != "q" ] && afs='0' ## <-- default ai filter state ( 0 = [OFF] // 1 = [ON] )
dl_location="$(pwd)/r34-dl" ## <-- default download location

## check common deps
deps="grep curl shuf tput sed"
for dep in $deps; do
! command -v "$dep" >/dev/null && \
printf '%s\n' "--> ERROR: $dep MISSING." && exit 1 
done

## check for kitty & install it, if missing
! command -v kitten >/dev/null && {
[ ! -f "$kittypath/bin/kitten" ] && \
printf '\n--> DOWNLOADING KITTY..\n\n' && \
curl -sL 'https://sw.kovidgoyal.net/kitty/installer.sh' | sh /dev/stdin launch=n
[ -f "$kittypath/bin/kitten" ] && \
export kitten="$kittypath/bin/kitten" && \
export kitty="$kittypath/bin/kitty" || exit 1
}

## if we're using an unsupported terminal, re-launch in kitty
! $kitten icat --detect-support &>/dev/null && \
{ command -v "$kitty" >/dev/null  || [ -f "$kitty" ] ;} && \
printf '\n--> RE-LAUNCHING IN KITTY..\n\n' && \
{ $kitty -T "$0" "$0" &>/dev/null & exit ;}

## if $action is not q, obtain cookie
## (this way we only fetch it once)
[ "$action" != "q" ] && {
c="$(curl -sL "https://gist.github.com/ConzZah/8577f7431116e5b8b70a7347321c5c1f/raw")"
c="$(curl -sL "$c"| shuf -n1)" ## <-- choose random cookie
c="${c}; filter_ai=$afs" ## <-- apply default ai filter state
grep -vq 'cf_clearance' <<< "$c" && { printf '\n%s\n\n' '--> ERROR: COULD NOT OBTAIN COOKIE'; exit 1 ;}
}

## create tmpdir ##
## NOTE: /run/user/1000 is a portion of ram
## the goal is to not touch the disk unless downloading
[ "$action" != "q" ] && {
tmp="/run/user/1000"; [ -d "$tmp" ] && \
tmp="$(mktemp -d "${tmp}/r34-sh-tmp-XXX")" || exit 1 ;}

$kitten icat --clear
## show logo and search bar
printf  '%s\n\n' " == r34.sh // ConzZah // 2026 =="
curl -s 'https://rule34.xxx/images/headerru.png?v2' \
-H "User-Agent: $ua" \
-H "Accept: $image_header" \
-H "Cookie: $c" > "$tmp/image" && $kitten icat "$tmp/image" || exit 1
[ -z "$1" ] && printf '\n%s' "SEARCH --> " && read -r search
[ -n "$1" ] && search="$*"
search="${search// /+}"
main
}


main () {
get_ai_filter_state
action=""; fetch_page
until [ -n "$x" ]; do
read -r -s -n1 action
case $action in

## THUMBNAIL ACTIONS ##
d|D) next_thumb ;;
a|A) prev_thumb ;;

## PAGE ACTIONS ##
w|W) page_up   ;;
s|S) page_down ;;

## DOWNLOAD ##
c|C) fetch_fullsize && download ;;

## FULLSIZE ##
f|F) fetch_fullsize || fetch_thumb ;;

## TOGGLE AI FILTER ##
i|I) toggle_ai_filter ;;

## GO BACK TO SEARCH ##
q|Q) init ;;

## cooldown for when nothing matched ##
*) sleep 0.3 ;;

esac
action=""
done
}

next_thumb () {
[ "$tc" = "$max_tc" ] && [ "$max_tc" = '42' ] && page_up && return
[ "$tc" -ne "$max_tc" ] && tc=$((tc + 1)) && fetch_thumb ;}

prev_thumb () {
[ "$tc" = "1" ] && [ "$pid" -gt "0" ] && page_down && return
[ "$tc" -ne "1" ] && tc=$((tc - 1)) && fetch_thumb ;}

page_up () { [ "$max_tc" = "42" ] && pid=$((pid + max_tc)) && page_counter=$((page_counter + 1)) && fetch_page ;}
page_down () { [ "$pid" -ne "0" ] && pid=$((pid - max_tc)) && page_counter=$((page_counter - 1)) && fetch_page ;}


fetch_page () {
tc="1" ## <-- reset thumbnail-counter to 1 whenever we call this function
curl -# "https://rule34.xxx/index.php?page=post&s=list&tags=${search}&pid=${pid}" \
--compressed \
-H "User-Agent: $ua" \
-H 'Accept-Language: en-US,en;q=0.9' \
-H 'Referer: https://rule34.xxx/' \
-H "Cookie: $c" \
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
-H 'TE: trailers' > "$tmp/.html" || exit 1

## get the thumbnails 
grep -o '.*thumbnails.*' "$tmp/.html"| cut -d '"' -f 2 > "$tmp/.thumbs"

## if $max_tc is 0 then we have no results
max_tc="$(wc -l "$tmp/.thumbs"| cut -d ' ' -f 1)"
[ "$max_tc" = "0" ] && printf '\n%s\n\n' '--> NOBODY HERE BUT US CHICKENS!' && sleep 1 && init
fetch_thumb
}


fetch_thumb () {
curl -# "$(sed -n "$tc p" "$tmp/.thumbs")" \
-H "Cookie: $c" \
-H "User-Agent: $ua" \
-H "Accept: $image_header" \
-H 'Referer: https://rule34.xxx/' > "$tmp/image" && \
$kitten icat --clear; clear
printf "%s\n\n" "PAGE: $page_counter /// PAGE-ITEM: ${tc}/${max_tc}"
$kitten icat --align left "$tmp/image" || exit 1
rm -f "$tmp/image"
show_controls
}


fetch_fullsize () {
url=""; id=""
id="$(sed -n "$tc p" "$tmp/.thumbs"| cut -d '?' -f 2)"
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
-H "Cookie: $c" \
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

## if $action = c, we're downloading the image or video, 
## and skipping the fullscreen display by returning
[ "$action" = "c" ] && return

$kitten icat --clear; clear
curl -s "$url" \
-H "User-Agent: $ua" \
-H "Accept: $image_header" \
-H 'Accept-Language: en-US,en;q=0.9' \
-H 'Accept-Encoding: gzip, deflate, br, zstd' \
-H 'DNT: 1' \
-H 'Sec-GPC: 1' \
-H 'Connection: keep-alive' \
-H 'Referer: https://rule34.xxx/' \
-H "Cookie: $c" \
-H 'Sec-Fetch-Dest: image' \
-H 'Sec-Fetch-Mode: no-cors' \
-H 'Sec-Fetch-Site: same-site' \
-H 'Priority: u=5, i' \
-H 'Pragma: no-cache' \
-H 'Cache-Control: no-cache' \
-H 'TE: trailers' > "$tmp/image"
$kitten icat -n --align left --use-window-size "$(tput cols),$(tput lines),$($kitten icat --print-window-size| sed 's#x#,#')" "$tmp/image" || exit 1
rm -f "$tmp/image"
}


download () {
mkdir -p "$dl_location" && cd "$dl_location" || exit 1
printf '%s\n' "--> DOWNLOADING: $url"
curl -O# -H "User-Agent: $ua" "$url" && \
sleep 0.4 && cd - || exit 1
fetch_thumb
}


get_ai_filter_state () {
## get ai_filter_state
## and set new_ai_filter_state to the opposite
afs="$(echo "$c"| rev| cut -c 1)" 
[ "$afs" = "0" ] && afs_hr='[OFF]' && new_afs="1" && new_afs_hr="[ON]"
[ "$afs" = "1" ] && afs_hr='[ON]' && new_afs="0" && new_afs_hr="[OFF]"
}


toggle_ai_filter () {
get_ai_filter_state
## change ai filter state
c="${c/filter_ai=$afs/filter_ai=$new_afs}"
afs="$new_afs"; afs_hr="$new_afs_hr"
printf '\n%s\n\n' '--> RELOADING'
rm -f "$tmp/.html" "$tmp/.thumbs"
sleep 0.1
main
}


show_controls () {
printf '\n%s' "~~~ [i] = AI FILTER: $afs_hr ~~~"
printf '\n[c] = DOWNLOAD [f] = FULL-SIZE\n[w] = PAGE UP  [s] = PAGE DOWN\n[a] = PREV     [d] = NEXT\n\n'
}


cleanup () { rm -rf "$tmp" &>/dev/null; exit ;}

trap cleanup INT QUIT TERM EXIT

#### LAUNCH ####
init "$@"
