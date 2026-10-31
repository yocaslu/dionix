# Convertido de dot_config/waybar/config.jsonc (yocaslu/dotfiles)
colors: {
  position = "bottom";
  height = 28;
  spacing = 4;
  modules-left = [
    "sway/workspaces"
    "sway/mode"
    "sway/scratchpad"
  ];
  modules-center = [ "sway/window" ];
  modules-right = [
    "mpd"
    "custom/cava"
    "idle_inhibitor"
    "pulseaudio"
    "network"
    "group/sys"
    "backlight"
    "sway/language"
    "battery"
    "battery#bat2"
    "custom/updates"
    "custom/weather"
    "custom/notification"
    "clock"
    "tray"
    "custom/power"
  ];
  "sway/workspaces" = {
    disable-scroll = true;
    all-outputs = true;
    warp-on-scroll = false;
    format = "{name}";
  };
  "sway/mode" = {
    format = "-- {} --";
  };
  "sway/scratchpad" = {
    format = "<span alpha='55%'>scr</span> {count}";
    show-empty = false;
    tooltip = true;
    tooltip-format = "{app}: {title}";
  };
  "sway/window" = {
    format = "{title}";
    max-length = 80;
  };
  mpd = {
    format = "<span alpha='55%'>mpd</span> {stateIcon} {artist} - {title}";
    format-disconnected = "<span alpha='55%'>mpd</span> off";
    format-stopped = "<span alpha='55%'>mpd</span> ■";
    max-length = 50;
    state-icons = {
      paused = "‖";
      playing = "▶";
    };
    tooltip-format = "{elapsedTime:%M:%S}/{totalTime:%M:%S} ({songPosition}|{queueLength})";
  };
  idle_inhibitor = {
    format = "<span alpha='55%'>idle</span> {icon}";
    format-icons = {
      activated = "off";
      deactivated = "on";
    };
  };
  tray = {
    spacing = 8;
  };
  clock = {
    format = "{:%H:%M}";
    format-alt = "{:%a %d/%m/%Y}";
    tooltip-format = "<tt><small>{calendar}</small></tt>";
    calendar = {
      format = {
        months = "<span color='${colors.base0E}'><b>{}</b></span>";
        weekdays = "<span color='${colors.base03}'>{}</span>";
        today = "<span color='${colors.base08}'><b><u>{}</u></b></span>";
      };
    };
  };
  temperature = {
    critical-threshold = 80;
    format = "<span alpha='55%'>tmp</span> {icon} {temperatureC}°C";
    format-icons = [
      "▁"
      "▂"
      "▃"
      "▄"
      "▅"
      "▆"
      "▇"
      "█"
    ];
  };
  backlight = {
    format = "<span alpha='55%'>lum</span> {icon} {percent}%";
    format-icons = [
      "▁"
      "▂"
      "▃"
      "▄"
      "▅"
      "▆"
      "▇"
      "█"
    ];
  };
  battery = {
    states = {
      warning = 30;
      critical = 15;
    };
    format = "<span alpha='55%'>bat</span> {icon} {capacity}%";
    format-full = "<span alpha='55%'>bat</span> █ 100%";
    format-charging = "<span alpha='55%'>bat</span> ↑ {capacity}%";
    format-plugged = "<span alpha='55%'>bat</span> = {capacity}%";
    format-alt = "<span alpha='55%'>bat</span> {icon} {time}";
    format-icons = [
      "▁"
      "▂"
      "▃"
      "▄"
      "▅"
      "▆"
      "▇"
      "█"
    ];
  };
  "battery#bat2" = {
    bat = "BAT2";
  };
  power-profiles-daemon = {
    format = "<span alpha='55%'>pwr</span> {icon}";
    tooltip-format = "Power profile: {profile}\nDriver: {driver}";
    tooltip = true;
    format-icons = {
      default = "?";
      performance = "perf";
      balanced = "bal";
      power-saver = "eco";
    };
  };
  network = {
    format-wifi = "<span alpha='55%'>net</span> {icon} {essid}";
    format-ethernet = "<span alpha='55%'>eth</span> {ipaddr}";
    tooltip-format = "{ifname} via {gwaddr}";
    format-linked = "<span alpha='55%'>net</span> no ip";
    format-disconnected = "<span alpha='55%'>net</span> down";
    format-alt = "<span alpha='55%'>net</span> {icon} {signalStrength}%";
    on-click-right = "nm-connection-editor";
    format-icons = [
      "▁"
      "▂"
      "▃"
      "▄"
      "▅"
      "▆"
      "▇"
      "█"
    ];
  };
  bluetooth = {
    format = "<span alpha='55%'>bt</span> {status}";
    format-connected = "<span alpha='55%'>bt</span> {device_alias}";
    format-connected-battery = "<span alpha='55%'>bt</span> {device_alias} {device_battery_percentage}%";
    on-click = "blueman-manager";
    on-click-right = "bluetoothctl power toggle";
  };
  pulseaudio = {
    format = "<span alpha='55%'>vol</span> {icon} {volume}%{format_source}";
    format-bluetooth = "<span alpha='55%'>vol</span> {icon} {volume}% bt{format_source}";
    format-bluetooth-muted = "<span alpha='55%'>vol</span> mute bt{format_source}";
    format-muted = "<span alpha='55%'>vol</span> mute{format_source}";
    format-source = "";
    format-source-muted = " <span alpha='55%'>mic</span> off";
    format-icons = {
      default = [
        "▁"
        "▂"
        "▃"
        "▄"
        "▅"
        "▆"
        "▇"
        "█"
      ];
    };
    on-click = "pavucontrol";
  };
  "custom/notification" = {
    format = "<span alpha='55%'>ntf</span> {icon}";
    format-icons = {
      notification = "●";
      none = "○";
      dnd-notification = "dnd ●";
      dnd-none = "dnd ○";
      inhibited-notification = "●";
      inhibited-none = "○";
      dnd-inhibited-notification = "dnd ●";
      dnd-inhibited-none = "dnd ○";
    };
    tooltip = false;
    return-type = "json";
    exec-if = "which swaync-client";
    exec = "swaync-client -swb";
    on-click = "swaync-client -t -sw";
    on-click-right = "swaync-client -d -sw";
    escape = true;
  };
  "group/sys" = {
    orientation = "inherit";
    drawer = {
      transition-duration = 300;
      children-class = "drawer-child";
      transition-left-to-right = false;
    };
    modules = [
      "custom/sys"
      "bluetooth"
      "temperature"
      "power-profiles-daemon"
    ];
  };
  "custom/sys" = {
    format = "<span alpha='55%'>sys</span> «";
    tooltip-format = "bluetooth, temperatura e perfil de energia";
  };
  "custom/cava" = {
    exec = "~/.config/waybar/scripts/cava.sh";
    format = "{}";
    tooltip = false;
    escape = true;
  };
  "custom/updates" = {
    exec = "~/.config/waybar/scripts/updates.sh";
    return-type = "json";
    format = "<span alpha='55%'>upd</span> {}";
    interval = 1800;
    signal = 8;
    on-click = "alacritty -e ~/.config/waybar/scripts/updates.sh --upgrade";
  };
  "custom/weather" = {
    exec = "~/.config/waybar/scripts/weather.sh";
    return-type = "json";
    format = "<span alpha='55%'>wx</span> {}";
    interval = 1800;
    on-click = "alacritty --hold -e ~/.config/waybar/scripts/weather.sh --full";
  };
  "custom/power" = {
    format = "⏻";
    tooltip = false;
    on-click = "wlogout -b 5 -T 440 -B 440";
  };
  "sway/language" = {
    format = "<span alpha='55%'>kbd</span> {short}";
    on-click = "swaymsg input type:keyboard xkb_switch_layout next";
  };
}
