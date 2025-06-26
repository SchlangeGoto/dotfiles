#!/bin/bash

# Set theme, replace "Dribbblish" with your theme
spicetify config current_theme Dribbblish

# Set color scheme, replace "catppuccin-mocha" with your scheme. Remove this line if no scheme
spicetify config color_scheme catppuccin-mocha

# Apply the new theme settings
spicetify watch -s &
sleep 1 && pkill spicetify
