#!/bin/bash

# Color configuration
COLOR_ACTIVE="${DWM_TAG_ACTIVE_COLOR:-#eceff4}"
COLOR_OCCUPIED="${DWM_TAG_OCCUPIED_COLOR:-#d8dee9}"
COLOR_URGENT="${DWM_TAG_URGENT_COLOR:-#bf616a}"
COLOR_EMPTY="${DWM_TAG_EMPTY_COLOR:-#4c566a}"
FONT_ACTIVE="${DWM_TAG_ACTIVE_FONT:-2}"
FONT_OCCUPIED="${DWM_TAG_OCCUPIED_FONT:-4}"
FONT_URGENT="${DWM_TAG_URGENT_FONT:-4}"
FONT_EMPTY="${DWM_TAG_EMPTY_FONT:-4}"

# Switch DWM tag by simulating the keybind (Super+1 through Super+9)
# DWM's default tag keybinds are Mod+1-9
switch_tag() {
    local tag=$1  # 1-9
    xdotool key "super+$tag"
}

update_tags() {
    declare -A occupied_tags
    declare -A urgent_tags

    client_list=$(xprop -root _NET_CLIENT_LIST 2>/dev/null | cut -d'#' -f2)

    if [ -n "$client_list" ]; then
        while IFS= read -r win_id; do
            win_id="${win_id// /}"
            [ -z "$win_id" ] && continue
            desktop=$(xprop -id "$win_id" _NET_WM_DESKTOP 2>/dev/null | awk '{print $3}')
            if [ -n "$desktop" ] && [ "$desktop" != "4294967295" ]; then
                occupied_tags[$desktop]=1
                hints=$(xprop -id "$win_id" WM_HINTS 2>/dev/null)
                if echo "$hints" | grep -q "urgency hint"; then
                    urgent_tags[$desktop]=1
                fi
            fi
        done < <(tr ',' '\n' <<< "$client_list")
    fi

    current=$(xprop -root _NET_CURRENT_DESKTOP 2>/dev/null | awk '{print $3}')
    current=${current:-0}

    output=""
    for i in {0..8}; do
        tag=$((i + 1))

        # Call this script with --switch <tag> on click
        click_action="%{A1:$0 --switch $tag:}"
        click_end="%{A}"

        if [ "$i" = "$current" ]; then
            output+="${click_action}%{F${COLOR_ACTIVE}}%{T${FONT_ACTIVE}} $tag %{T-}%{F-}${click_end}"
        elif [ "${urgent_tags[$i]}" = "1" ]; then
            output+="${click_action}%{F${COLOR_URGENT}}%{T${FONT_URGENT}} $tag %{T-}%{F-}${click_end}"
        elif [ "${occupied_tags[$i]}" = "1" ]; then
            output+="${click_action}%{F${COLOR_OCCUPIED}}%{T${FONT_OCCUPIED}} $tag %{T-}%{F-}${click_end}"
        else
            output+="${click_action}%{F${COLOR_EMPTY}}%{T${FONT_EMPTY}} $tag %{T-}%{F-}${click_end}"
        fi
    done

    echo "$output"
}

case "$1" in
    --switch)
        switch_tag "$2"
        ;;
    --tail)
        update_tags
        xprop -root -spy _NET_CURRENT_DESKTOP _NET_CLIENT_LIST DWM_TAG_UPDATE 2>/dev/null | \
        while IFS= read -r line; do
            case "$line" in
                _NET_CURRENT_DESKTOP*|_NET_CLIENT_LIST*|DWM_TAG_UPDATE*)
                    update_tags ;;
            esac
        done
        ;;
    *)
        update_tags
        ;;
esac