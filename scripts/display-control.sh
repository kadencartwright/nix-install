set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/display-control"
state_file="$state_dir/layout"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/display-control"
ddc_cache="$runtime_dir/ddc-detect"

monitors_json() {
  hyprctl monitors all -j
}

is_internal() {
  [[ "$1" =~ ^(eDP|LVDS|DSI)-?[0-9]*$ ]]
}

backlight_device() {
  local device
  for device in gmux_backlight amdgpu_bl1 amdgpu_bl0 intel_backlight acpi_video0; do
    if [[ -e "/sys/class/backlight/$device/brightness" ]]; then
      printf '%s\n' "$device"
      return 0
    fi
  done

  brightnessctl --list --machine-readable 2>/dev/null \
    | awk -F, '$2 == "backlight" { print $1; exit }'
}

ddc_snapshot=""
ddc_snapshot_loaded=false
load_ddc_snapshot() {
  local now modified tmp
  if [[ "$ddc_snapshot_loaded" == false ]]; then
    mkdir -p "$runtime_dir"
    now=$(date +%s)
    modified=$(stat --format=%Y "$ddc_cache" 2>/dev/null || printf '0')
    if (( now - modified < 300 )); then
      ddc_snapshot=$(<"$ddc_cache")
    else
      tmp=$(mktemp "$runtime_dir/ddc-detect.XXXXXX")
      ddcutil --skip-ddc-checks detect --brief > "$tmp" 2>/dev/null || true
      mv "$tmp" "$ddc_cache"
      ddc_snapshot=$(<"$ddc_cache")
    fi
    ddc_snapshot_loaded=true
  fi
}

ddc_bus_for() {
  local monitor=$1
  load_ddc_snapshot
  awk -v target="$monitor" '
    /^Display [0-9]+/ { bus=""; connector="" }
    /I2C bus:[[:space:]]*\/dev\/i2c-/ {
      bus=$0
      sub(/^.*\/dev\/i2c-/, "", bus)
      sub(/[[:space:]].*$/, "", bus)
    }
    /DRM connector:/ {
      connector=$0
      sub(/^.*DRM connector:[[:space:]]*/, "", connector)
      sub(/^card[0-9]+-/, "", connector)
      sub(/[[:space:]].*$/, "", connector)
      if (connector == target && bus != "") { print bus; exit }
    }
  ' <<< "$ddc_snapshot"
}

read_brightness() {
  local monitor=$1 device bus response current maximum
  if is_internal "$monitor"; then
    device=$(backlight_device)
    [[ -n "$device" ]] || return 1
    brightnessctl --device "$device" --machine-readable info 2>/dev/null \
      | awk -F, 'NR == 1 { gsub(/%/, "", $4); print $4 }'
    return
  fi

  bus=$(ddc_bus_for "$monitor")
  [[ -n "$bus" ]] || return 1
  response=$(ddcutil --bus "$bus" --skip-ddc-checks getvcp 10 --brief 2>/dev/null || true)
  read -r current maximum < <(awk '$1 == "VCP" && $2 == "10" { print $(NF-1), $NF; exit }' <<< "$response")
  [[ "$current" =~ ^[0-9]+$ && "$maximum" =~ ^[0-9]+$ && "$maximum" -gt 0 ]] || return 1
  awk -v current="$current" -v maximum="$maximum" 'BEGIN { printf "%d\n", (current * 100 / maximum) + 0.5 }'
}

focused_monitor() {
  monitors_json | jq -r '[.[] | select(.focused == true)][0].name // [.[] | select(.disabled != true)][0].name // empty'
}

main_brightness_monitor() {
  local json preferred monitor value
  json=$(monitors_json)
  preferred=$(jq -r '[.[] | select(.disabled != true)] | sort_by(.y, .x) | .[0].name // empty' <<< "$json")
  if [[ -n "$preferred" ]]; then
    value=$(read_brightness "$preferred" 2>/dev/null || true)
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      printf '%s\n' "$preferred"
      return 0
    fi
  fi
  while IFS= read -r monitor; do
    [[ "$monitor" == "$preferred" ]] && continue
    value=$(read_brightness "$monitor" 2>/dev/null || true)
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      printf '%s\n' "$monitor"
      return 0
    fi
  done < <(jq -r '.[] | select(.disabled != true) | .name' <<< "$json")
  return 1
}

set_brightness() {
  local monitor=$1 requested=$2 current target device bus response maximum raw
  if [[ "$monitor" == "focused" ]]; then
    monitor=$(focused_monitor)
  elif [[ "$monitor" == "main" ]]; then
    monitor=$(main_brightness_monitor)
  fi
  [[ -n "$monitor" ]] || { echo "No active monitor" >&2; return 1; }

  if [[ "$requested" =~ ^[+-][0-9]+$ ]]; then
    current=$(read_brightness "$monitor") || { echo "$monitor does not expose brightness control" >&2; return 1; }
    target=$((current + requested))
  else
    target=${requested%%%}
  fi
  [[ "$target" =~ ^[0-9]+$ ]] || { echo "Brightness must be a percentage or relative step" >&2; return 2; }
  (( target < 1 )) && target=1
  (( target > 100 )) && target=100

  if is_internal "$monitor"; then
    device=$(backlight_device)
    [[ -n "$device" ]] || { echo "No laptop backlight was found" >&2; return 1; }
    brightnessctl --device "$device" set "${target}%" >/dev/null
  else
    bus=$(ddc_bus_for "$monitor")
    [[ -n "$bus" ]] || { echo "$monitor does not expose DDC/CI" >&2; return 1; }
    response=$(ddcutil --bus "$bus" --skip-ddc-checks getvcp 10 --brief 2>/dev/null || true)
    maximum=$(awk '$1 == "VCP" && $2 == "10" { print $NF; exit }' <<< "$response")
    [[ "$maximum" =~ ^[0-9]+$ && "$maximum" -gt 0 ]] || { echo "$monitor rejected DDC brightness control" >&2; return 1; }
    raw=$((target * maximum / 100))
    ddcutil --bus "$bus" --skip-ddc-checks --noverify setvcp 10 "$raw" >/dev/null
  fi
  printf '%s\n' "$target"
}

mode_for() {
  local json=$1 name=$2
  jq -r --arg name "$name" '
    .[] | select(.name == $name) |
    if (.width // 0) > 0 and (.height // 0) > 0 then
      "\(.width)x\(.height)@\(.refreshRate)"
    else "preferred" end
  ' <<< "$json"
}

scale_for() {
  local json=$1 name=$2
  jq -r --arg name "$name" '.[] | select(.name == $name) | .scale // 1' <<< "$json"
}

logical_size_for() {
  local json=$1 name=$2
  jq -r --arg name "$name" '
    .[] | select(.name == $name) |
    [(((.width // 0) / (.scale // 1)) | round), (((.height // 0) / (.scale // 1)) | round)] | @tsv
  ' <<< "$json"
}

enabled_names() {
  local json=$1 axis=$2
  if [[ "$axis" == "vertical" ]]; then
    jq -r '[.[] | select(.disabled != true)] | sort_by(.y, .x) | .[].name' <<< "$json"
  else
    jq -r '[.[] | select(.disabled != true)] | sort_by(.x, .y) | .[].name' <<< "$json"
  fi
}

disabled_specs() {
  local json=$1
  jq -r '.[] | select(.disabled == true) | "\(.name),disable"' <<< "$json"
}

save_and_apply() {
  local tmp
  mkdir -p "$state_dir"
  tmp=$(mktemp "$state_dir/layout.XXXXXX")
  cat > "$tmp"
  mv "$tmp" "$state_file"
  apply_layout "$state_file"
}

lua_string() {
  jq -Rrn --arg value "$1" '$value | @json'
}

apply_layout() {
  local source=$1 spec output mode position scale option target extra code="" scale_value
  while IFS= read -r spec; do
    [[ -n "$spec" ]] || continue
    IFS=',' read -r output mode position scale option target extra <<< "$spec"
    [[ -n "$output" && -n "$mode" && -z "$extra" ]] \
      || { echo "Invalid saved monitor configuration: $spec" >&2; return 1; }

    if [[ "$mode" == "disable" ]]; then
      code+="hl.monitor({ output = $(lua_string "$output"), disabled = true });"
      continue
    fi

    [[ -n "$position" && -n "$scale" ]] \
      || { echo "Incomplete saved monitor configuration: $spec" >&2; return 1; }
    if [[ "$scale" == "auto" ]]; then
      scale_value='"auto"'
    elif [[ "$scale" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      scale_value=$scale
    else
      echo "Invalid monitor scale in saved configuration: $spec" >&2
      return 1
    fi

    code+="hl.monitor({ output = $(lua_string "$output"), mode = $(lua_string "$mode"), position = $(lua_string "$position"), scale = $scale_value"
    if [[ "$option" == "mirror" && -n "$target" ]]; then
      code+=", mirror = $(lua_string "$target")"
    elif [[ -n "$option" || -n "$target" ]]; then
      echo "Invalid monitor option in saved configuration: $spec" >&2
      return 1
    fi
    code+=" });"
  done < "$source"

  [[ -n "$code" ]] || return 0
  hyprctl eval "$code" >/dev/null
}

arrange() {
  local axis=$1 preferred=${2:-} json x=0 y=0 name mode scale width height
  local -a names=()
  json=$(monitors_json)
  mapfile -t names < <(enabled_names "$json" "$axis")

  if [[ -n "$preferred" ]]; then
    local found=-1 index
    for index in "${!names[@]}"; do
      [[ "${names[$index]}" == "$preferred" ]] && found=$index
    done
    if (( found >= 0 )); then
      unset 'names[found]'
      names=("$preferred" "${names[@]}")
    fi
  fi

  {
    for name in "${names[@]}"; do
      mode=$(mode_for "$json" "$name")
      scale=$(scale_for "$json" "$name")
      printf '%s,%s,%sx%s,%s\n' "$name" "$mode" "$x" "$y" "$scale"
      read -r width height < <(logical_size_for "$json" "$name")
      if [[ "$axis" == "vertical" ]]; then
        y=$((y + height))
      else
        x=$((x + width))
      fi
    done
    disabled_specs "$json"
  } | save_and_apply
}

move_monitor() {
  local monitor=$1 direction=$2 axis delta json index=-1 swap
  local -a names=()
  case "$direction" in
    left) axis=horizontal; delta=-1 ;;
    right) axis=horizontal; delta=1 ;;
    up) axis=vertical; delta=-1 ;;
    down) axis=vertical; delta=1 ;;
    *) echo "Unknown direction: $direction" >&2; return 2 ;;
  esac
  json=$(monitors_json)
  mapfile -t names < <(enabled_names "$json" "$axis")
  for swap in "${!names[@]}"; do
    [[ "${names[$swap]}" == "$monitor" ]] && index=$swap
  done
  (( index >= 0 )) || { echo "Unknown active monitor: $monitor" >&2; return 1; }
  swap=$((index + delta))
  (( swap >= 0 && swap < ${#names[@]} )) || return 0
  local temporary=${names[swap]}
  names[swap]=${names[index]}
  names[index]=$temporary

  local x=0 y=0 name mode scale width height
  {
    for name in "${names[@]}"; do
      mode=$(mode_for "$json" "$name")
      scale=$(scale_for "$json" "$name")
      printf '%s,%s,%sx%s,%s\n' "$name" "$mode" "$x" "$y" "$scale"
      read -r width height < <(logical_size_for "$json" "$name")
      if [[ "$axis" == "vertical" ]]; then y=$((y + height)); else x=$((x + width)); fi
    done
    disabled_specs "$json"
  } | save_and_apply
}

position_monitor() {
  local monitor=$1 new_x=$2 new_y=$3 json name mode scale x y
  [[ "$new_x" =~ ^-?[0-9]+$ && "$new_y" =~ ^-?[0-9]+$ ]] \
    || { echo "Display coordinates must be integers" >&2; return 2; }
  json=$(monitors_json)
  jq -e --arg name "$monitor" '.[] | select(.name == $name and .disabled != true)' <<< "$json" >/dev/null \
    || { echo "Unknown active monitor: $monitor" >&2; return 1; }

  {
    while IFS= read -r name; do
      mode=$(mode_for "$json" "$name")
      scale=$(scale_for "$json" "$name")
      if [[ "$name" == "$monitor" ]]; then
        x=$new_x
        y=$new_y
      else
        read -r x y < <(jq -r --arg name "$name" '.[] | select(.name == $name) | [(.x // 0), (.y // 0)] | @tsv' <<< "$json")
      fi
      printf '%s,%s,%sx%s,%s\n' "$name" "$mode" "$x" "$y" "$scale"
    done < <(enabled_names "$json" horizontal)
    disabled_specs "$json"
  } | save_and_apply
}

position_monitors() {
  (( $# > 0 && $# % 3 == 0 )) \
    || { echo "Usage: display-control positions MONITOR X Y [MONITOR X Y ...]" >&2; return 2; }
  local json name mode scale x y
  declare -A requested_x=() requested_y=()
  json=$(monitors_json)

  while (( $# > 0 )); do
    name=$1
    x=$2
    y=$3
    [[ "$x" =~ ^-?[0-9]+$ && "$y" =~ ^-?[0-9]+$ ]] \
      || { echo "Display coordinates must be integers" >&2; return 2; }
    jq -e --arg name "$name" '.[] | select(.name == $name and .disabled != true)' <<< "$json" >/dev/null \
      || { echo "Unknown active monitor: $name" >&2; return 1; }
    requested_x["$name"]=$x
    requested_y["$name"]=$y
    shift 3
  done

  {
    while IFS= read -r name; do
      mode=$(mode_for "$json" "$name")
      scale=$(scale_for "$json" "$name")
      if [[ -v 'requested_x[$name]' ]]; then
        x=${requested_x[$name]}
        y=${requested_y[$name]}
      else
        read -r x y < <(jq -r --arg name "$name" '.[] | select(.name == $name) | [(.x // 0), (.y // 0)] | @tsv' <<< "$json")
      fi
      printf '%s,%s,%sx%s,%s\n' "$name" "$mode" "$x" "$y" "$scale"
    done < <(enabled_names "$json" horizontal)
    disabled_specs "$json"
  } | save_and_apply
}

mirror_all() {
  local target=$1 json name target_mode target_scale
  json=$(monitors_json)
  jq -e --arg name "$target" '.[] | select(.name == $name and .disabled != true)' <<< "$json" >/dev/null \
    || { echo "Choose an active monitor to mirror" >&2; return 1; }
  target_mode=$(mode_for "$json" "$target")
  target_scale=$(scale_for "$json" "$target")
  {
    printf '%s,%s,0x0,%s\n' "$target" "$target_mode" "$target_scale"
    while IFS= read -r name; do
      [[ "$name" == "$target" ]] && continue
      printf '%s,preferred,0x0,auto,mirror,%s\n' "$name" "$target"
    done < <(enabled_names "$json" horizontal)
    disabled_specs "$json"
  } | save_and_apply
}

status_json() {
  local json monitors name brightness kind mode
  json=$(monitors_json)
  monitors=$(jq '[.[] | {
    name,
    description: (.description // .name),
    width: (.width // 0), height: (.height // 0),
    x: (.x // 0), y: (.y // 0), scale: (.scale // 1),
    refreshRate: (.refreshRate // 0),
    enabled: (.disabled != true), focused: (.focused == true),
    mirror: ((.mirror // .mirrorOf // "") | if . == "none" then "" else . end),
    brightnessAvailable: false, brightness: 0, brightnessKind: ""
  }]' <<< "$json")

  while IFS= read -r name; do
    brightness=$(read_brightness "$name" 2>/dev/null || true)
    [[ "$brightness" =~ ^[0-9]+$ ]] || continue
    if is_internal "$name"; then kind=Backlight; else kind=DDC/CI; fi
    monitors=$(jq --arg name "$name" --arg kind "$kind" --argjson value "$brightness" '
      map(if .name == $name then . + {brightnessAvailable: true, brightness: $value, brightnessKind: $kind} else . end)
    ' <<< "$monitors")
  done < <(jq -r '.[] | select(.disabled != true) | .name' <<< "$json")

  mode=$(jq -r 'if any(.[]; .mirror != "") then "mirror" else "extend" end' <<< "$monitors")
  jq -cn --arg mode "$mode" --argjson monitors "$monitors" '{mode: $mode, monitors: $monitors}'
}

layout_status_json() {
  local monitors mode
  monitors=$(monitors_json | jq '[.[] | {
    name,
    description: (.description // .name),
    width: (.width // 0), height: (.height // 0),
    x: (.x // 0), y: (.y // 0), scale: (.scale // 1),
    refreshRate: (.refreshRate // 0),
    enabled: (.disabled != true), focused: (.focused == true),
    mirror: ((.mirror // .mirrorOf // "") | if . == "none" then "" else . end)
  }]')
  mode=$(jq -r 'if any(.[]; .mirror != "") then "mirror" else "extend" end' <<< "$monitors")
  jq -cn --arg mode "$mode" --argjson monitors "$monitors" '{mode: $mode, monitors: $monitors}'
}

brightness_status_json() {
  local json readings='{}' name brightness kind
  json=$(monitors_json)
  while IFS= read -r name; do
    brightness=$(read_brightness "$name" 2>/dev/null || true)
    [[ "$brightness" =~ ^[0-9]+$ ]] || continue
    if is_internal "$name"; then kind=Backlight; else kind=DDC/CI; fi
    readings=$(jq --arg name "$name" --arg kind "$kind" --argjson value "$brightness" \
      '. + {($name): {brightness: $value, brightnessKind: $kind}}' <<< "$readings")
  done < <(jq -r '.[] | select(.disabled != true) | .name' <<< "$json")
  jq -cn --argjson readings "$readings" '{readings: $readings}'
}

restore_layout() {
  [[ -s "$state_file" ]] || return 0
  apply_layout "$state_file"
}

command=${1:-status}
case "$command" in
  status) status_json ;;
  layout-status) layout_status_json ;;
  brightness-status) brightness_status_json ;;
  focused-brightness)
    monitor=$(focused_monitor)
    [[ -n "$monitor" ]] && read_brightness "$monitor"
    ;;
  main-brightness)
    monitor=$(main_brightness_monitor)
    [[ -n "$monitor" ]] && read_brightness "$monitor"
    ;;
  brightness-value)
    [[ $# -eq 2 ]] || { echo "Usage: display-control brightness-value MONITOR" >&2; exit 2; }
    read_brightness "$2"
    ;;
  brightness)
    [[ $# -eq 3 ]] || { echo "Usage: display-control brightness MONITOR PERCENT|+STEP|-STEP" >&2; exit 2; }
    set_brightness "$2" "$3"
    ;;
  extend) arrange horizontal ;;
  arrange)
    [[ ${2:-} == "horizontal" || ${2:-} == "vertical" ]] || { echo "Usage: display-control arrange horizontal|vertical" >&2; exit 2; }
    arrange "$2"
    ;;
  move)
    [[ $# -eq 3 ]] || { echo "Usage: display-control move MONITOR left|right|up|down" >&2; exit 2; }
    move_monitor "$2" "$3"
    ;;
  position)
    [[ $# -eq 4 ]] || { echo "Usage: display-control position MONITOR X Y" >&2; exit 2; }
    position_monitor "$2" "$3" "$4"
    ;;
  positions)
    position_monitors "${@:2}"
    ;;
  mirror)
    [[ $# -eq 2 ]] || { echo "Usage: display-control mirror TARGET" >&2; exit 2; }
    mirror_all "$2"
    ;;
  restore) restore_layout ;;
  *) echo "Unknown command: $command" >&2; exit 2 ;;
esac
