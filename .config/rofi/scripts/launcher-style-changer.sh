#!/usr/bin/env bash
#  ┳┓┏┓┏┓┳  ┓ ┏┓┳┳┳┓┏┓┓┏┏┓┳┓  ┏┓┏┳┓┓┏┓ ┏┓  ┏┓┏┓┓ ┏┓┏┓┏┳┓┏┓┳┓
#  ┣┫┃┃┣ ┃━━┃ ┣┫┃┃┃┃┃ ┣┫┣ ┣┫━━┗┓ ┃ ┗┫┃ ┣ ━━┗┓┣ ┃ ┣ ┃  ┃ ┃┃┣┫
#  ┛┗┗┛┻ ┻  ┗┛┛┗┗┛┛┗┗┛┛┗┗┛┛┗  ┗┛ ┻ ┗┛┗┛┗┛  ┗┛┗┛┗┛┗┛┗┛ ┻ ┗┛┛┗
#

# Copyright: The Hyde Project

# Rofi vars
rofiStyleDir="$HOME/.config/rofi/themes"
rofiAssetDir="$HOME/.config/rofi/assets/select-pics"
rofiTheme="$HOME/.config/rofi/applets/selector.rasi"
rofi_config_file="$HOME/.config/rofi/config.rasi"
SED=$(which sed)

hypr_border=${hypr_border:-"$(hyprctl -j getoption decoration:rounding | jq '.int')"}

#// scale for monitor

mon_data=$(hyprctl -j monitors)
mon_x_res=$(jq '.[] | select(.focused==true) | if (.transform % 2 == 0) then .width else .height end' <<<"${mon_data}")
mon_scale=$(jq '.[] | select(.focused==true) | .scale' <<<"${mon_data}" | sed "s/\.//")
mon_x_res=$((mon_x_res * 100 / mon_scale))

#// generate config

#// set rofi scaling
font_scale=10

# set font name
font_name=${JetBrainsMono Nerd Font}

# set rofi font override
font_override="* {font: \"${font_name:-"JetBrainsMono Nerd Font"} ${font_scale}\";}"

elem_border=$((hypr_border * 5))
icon_border=$((elem_border - 5))
elm_width=$(((48) * font_scale))
max_avail=$((mon_x_res - (4 * font_scale)))
col_count=$((max_avail / elm_width))
[[ "${col_count}" -gt 5 ]] && col_count=5
r_override="window{width:100%;} 
            listview{columns:${col_count};} 
            element{orientation:vertical;border-radius:${elem_border}px;} 
            element-icon{border-radius:${icon_border}px;size:20em;} 
            element-text{enabled:false;}"

# Map the available style files into an array (style_files)
mapfile -t style_files < <(find -L "$rofiAssetDir" -type f -name '*.png')

# Extract the base name
style_names=()
for file in "${style_files[@]}"; do
  echo "$file"
  style_names+=("$(basename "$file")")
done

# Sort the (style_files) array
IFS=$'\n' style_names=($(sort -V <<<"${style_names[*]}"))
unset IFS

# Prepare the list for rofi with previews
rofi_list=""
for style_name in "${style_names[@]}"; do
  rofi_list+="${style_name}\x00icon\x1f${rofiAssetDir}/${style_name}\n"
done

# Present the list of styles using rofi and get the selected style
RofiSel=$(echo -en "$rofi_list" | rofi -dmenu -markup-rows -theme-str "$r_override" -theme "$rofiTheme")

# Set Rofi Style
if [ ! -z "${RofiSel}" ]; then
  theme_name=$(echo "$RofiSel" | awk -F '.' '{print $1}')
  theme_path_with_tilde="$rofiStyleDir/$theme_name"

  # If no @theme is in the file, add it
  if ! grep -q '^\s*@theme' "$rofi_config_file"; then
    echo -e "\n\n@theme \"$theme_path_with_tilde\"" >>"$rofi_config_file"
    echo "Added @theme \"$theme_path_with_tilde\" to $rofi_config_file"
  else
    $SED -i "s/^\(\s*@theme.*\)/\/\/\1/" "$rofi_config_file"
    echo -e "@theme \"$theme_path_with_tilde\"" >>"$rofi_config_file"
    echo "Updated @theme line to $theme_path_with_tilde"
  fi

  # Ensure no more than max # of lines with //@theme lines
  max_line="9"
  total_lines=$(grep -c '^\s*//@theme' "$rofi_config_file")

  if [ "$total_lines" -gt "$max_line" ]; then
    excess=$((total_lines - max_line))
    # Remove the oldest or the very top //@theme lines
    for i in $(seq 1 "$excess"); do
      $SED -i '0,/^\s*\/\/@theme/ { /^\s*\/\/@theme/ {d; q; }}' "$rofi_config_file"
    done
    echo "Removed excess //@theme lines"
  fi

  notify-send -e -h string:x-canonical-private-synchronous:rofi_notif -a "t1" -r 91190 -t 2200 -i "${rofiAssetDir}/${RofiSel}.png" " Rofi style ${RofiSel} applied..."
fi
