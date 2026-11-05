#!/bin/bash
# 1t-setup для Ubuntu — всё в одном файле:
#   установка по категориям, графические среды, запуск рабочего стола,
#   проверка мощности, чёрные рамки меню, ISO/EXE/DEB,
#   ПОЧИНКА (пакеты, звук, два динамика, отчёт-промпт),
#   зелёный прогресс-бар с бегущим бликом, выбор файла (диалог / обзор / путь).
# Запуск:  bash 1t-setup.sh

G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'

STATE="$HOME/.1t-setup"; mkdir -p "$STATE"
LOG="$STATE/install.log"; FAILED="$STATE/failed.list"; REPORT="$STATE/report.txt"
CONF="$STATE/config"
touch "$LOG" "$FAILED"
DE=xfce; GPU=native; COMP=none
[ -f "$CONF" ] && . "$CONF"
save_conf(){ printf 'DE=%s\nGPU=%s\nCOMP=%s\n' "$DE" "$GPU" "$COMP" >"$CONF"; }
pause(){ echo; read -rp "Enter..." _; }
ask_yn(){ local a; read -rp "$1 [y/N]: " a; [[ $a =~ ^([Yy]|[Yy][Ee][Ss]|[Дд]|[Дд][Аа])$ ]]; }

# ===== sudo (один раз спросим пароль) =====
if [ "$EUID" -ne 0 ]; then
  if ! sudo -v; then echo "${R}Нужен sudo.${N}"; exit 1; fi
  SUDO="sudo"
else
  SUDO=""
fi

run_logged(){
  echo "=== $(date '+%F %T') $*" >>"$LOG"
  $SUDO env DEBIAN_FRONTEND=noninteractive "$@" 2>&1 | tee -a "$LOG"
  return "${PIPESTATUS[0]}"
}

# =====================================================================
#  Прогресс-бар: зелёный, по заполненной части бежит светлый блик
# =====================================================================
trap 'printf "\e[?25h"' EXIT
BASE_R=6;   BASE_G=176; BASE_B=37
LITE_R=120; LITE_G=235; LITE_B=135
BAR_W=30; LAST_OUT=""

bar_line(){
  local pct=$1 fr=$2 w=$BAR_W i d k r g b filled=0 c span
  BAR_OUT=""
  if (( pct >= 0 )); then
    filled=$(( w * pct / 100 )); span=$(( filled + 10 )); c=$(( (fr/2) % span - 4 ))
  else
    span=$(( w + 10 )); c=$(( (fr/2) % span - 5 ))
  fi
  for (( i=0; i<w; i++ )); do
    d=$(( i>c ? i-c : c-i )); k=$(( d<5 ? 5-d : 0 ))
    if (( pct >= 0 )); then
      if (( i >= filled )); then r=45; g=45; b=45
      else r=$(( BASE_R+(LITE_R-BASE_R)*k/5 )); g=$(( BASE_G+(LITE_G-BASE_G)*k/5 )); b=$(( BASE_B+(LITE_B-BASE_B)*k/5 )); fi
    else
      if (( d <= 4 )); then r=$(( BASE_R+(LITE_R-BASE_R)*k/5 )); g=$(( BASE_G+(LITE_G-BASE_G)*k/5 )); b=$(( BASE_B+(LITE_B-BASE_B)*k/5 ))
      else r=45; g=45; b=45; fi
    fi
    BAR_OUT+=$'\e[38;2;'"$r;$g;${b}m█"
  done
}

run_bar(){
  local title="$1" out st pid fr=0 pct=-1 phase="" kind a b c line txt cols p rc
  shift
  out=$(mktemp "$STATE/out.XXXXXX"); st=$(mktemp "$STATE/st.XXXXXX")
  cols=$(tput cols 2>/dev/null || echo 50)
  BAR_W=$(( cols - 10 )); (( BAR_W > 40 )) && BAR_W=40; (( BAR_W < 10 )) && BAR_W=10
  echo "=== $(date '+%F %T') $*" >>"$LOG"
  ( DEBIAN_FRONTEND=noninteractive "$@" </dev/null >"$out" 2>&1 3>"$st" ) &
  pid=$!
  printf '\e[?25l\n\n'
  while kill -0 "$pid" 2>/dev/null; do
    if (( fr % 5 == 0 )); then
      line=$(tail -n 1 "$st" 2>/dev/null)
      if [[ $line == dlstatus:* || $line == pmstatus:* ]]; then
        IFS=: read -r kind a b c <<<"$line"
        b=${b%%.*}; [[ $b =~ ^[0-9]+$ ]] && pct=$b
        [[ $kind == dlstatus ]] && phase="Загрузка" || phase="Установка"
      fi
    fi
    txt="${phase:-Работаю}: $title"; (( ${#txt} > cols-3 )) && txt="${txt:0:cols-6}..."
    bar_line "$pct" "$fr"
    if (( pct >= 0 )); then p=$(printf '%3d%%' "$pct"); else p=" … "; fi
    printf '\e[2A\r\e[K %s%s%s\n\r\e[K %s\e[0m %s\n' "$B" "$txt" "$N" "$BAR_OUT" "$p"
    fr=$((fr+1)); sleep 0.04
  done
  wait "$pid"; rc=$?
  printf '\e[2A\r\e[J\e[?25h'
  cat "$out" >>"$LOG"; rm -f "$st"; LAST_OUT="$out"
  return $rc
}

job(){
  local title="$1" rc l err; shift
  run_bar "$title" "$@"; rc=$?
  if (( rc == 0 )); then
    sed -nE 's/^Get:[0-9]+ [^ ]+ [^ ]+ [^ ]+ ([^ ]+) .*\[([^]]+)\]$/\1 (\2)/p' "$LAST_OUT" \
      | while IFS= read -r l; do echo "${G}  ↓ скачан: $l${N}"; done
    echo "${G}✓ $title — успешно${N}"
  else
    echo "${R}✗ $title — ошибка (код $rc)${N}"
    err=$(grep -iE '^(E:|Err:)|error|unable|failed|cannot|not found|no space|denied|unmet' "$LAST_OUT" | tail -n 6)
    [ -z "$err" ] && err=$(tail -n 4 "$LAST_OUT")
    while IFS= read -r l; do echo "${R}  $l${N}"; done <<<"$err"
    echo "  Полный лог: $LOG"
  fi
  rm -f "$LAST_OUT"; return $rc
}

apt_get(){ $SUDO env DEBIAN_FRONTEND=noninteractive apt-get \
  -o APT::Status-Fd=3 \
  -o Dpkg::Options::=--force-confdef \
  -o Dpkg::Options::=--force-confold "$@"; }

# =====================================================================
#  Категории
# =====================================================================
CATS=("Видео и графика" "Звук" "Оболочки (shell)" "Графические среды" \
      "Пакеты для XFCE" "Композитор и темы" "Языки программирования" \
      "Пакеты и сервисы" "Виртуализация и эмуляция" "Приложения" "Ввод и сеть")

ITEMS=()
add(){ ITEMS+=("$1|$2|$3|$4|$5"); }

# ---------- особые пункты ----------
chk_ohmyzsh(){ [ -d "$HOME/.oh-my-zsh" ]; }
ins_ohmyzsh(){
  job "Установка git и zsh" apt_get install -y git zsh || return 1
  job "Скачивание Oh My Zsh" git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh "$HOME/.oh-my-zsh" || return 1
  [ -f "$HOME/.zshrc" ] || cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
}
chk_zshdef(){ [ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v zsh 2>/dev/null)" ]; }
ins_zshdef(){
  pkg_ok zsh || apt_get install -y zsh
  $SUDO chsh -s "$(command -v zsh)" "$USER"
}
chk_docker(){ command -v docker >/dev/null 2>&1; }
ins_docker(){
  job "Установка docker.io" apt_get install -y docker.io || return 1
  $SUDO usermod -aG docker "$USER" && echo "${Y}Перелогинься, чтобы docker заработал без sudo.${N}"
}

# ---------- Видео и графика ----------
add "Видео и графика" "Mesa (драйверы OpenGL)"             "mesa-utils libgl1-mesa-dri"
add "Видео и графика" "Vulkan (loader + tools + ICD)"      "libvulkan1 vulkan-tools mesa-vulkan-drivers"
add "Видео и графика" "mesa-demos (glxinfo, glxgears)"     "mesa-utils"
add "Видео и графика" "FFmpeg + mpv"                        "ffmpeg mpv"
add "Видео и графика" "Аппаратное декодирование (VA-API)"  "va-driver-all vdpau-va-driver"
# ---------- Звук ----------
add "Звук" "PulseAudio (сервер звука)"   "pulseaudio pulseaudio-utils"
add "Звук" "PipeWire (альтернатива)"     "pipewire pipewire-pulse wireplumber"
add "Звук" "SoX + mpg123"                "sox mpg123"
add "Звук" "pavucontrol (микшер, GUI)"   "pavucontrol"
add "Звук" "espeak-ng (синтез речи)"     "espeak-ng"
# ---------- Оболочки ----------
add "Оболочки (shell)" "bash"                          "bash"
add "Оболочки (shell)" "zsh"                           "zsh"
add "Оболочки (shell)" "Oh My Zsh"                     "@ohmyzsh"
add "Оболочки (shell)" "zsh как оболочка по умолчанию" "@zshdef"
add "Оболочки (shell)" "fish"                          "fish"
add "Оболочки (shell)" "tmux"                          "tmux"
add "Оболочки (shell)" "starship (красивый prompt)"    "starship"
# ---------- Графические среды ----------
add "Графические среды" "XFCE"                "xfce4 xfce4-terminal" "x11" "X"
add "Графические среды" "KDE Plasma"          "kde-plasma-desktop konsole dolphin" "x11" "X"
add "Графические среды" "MATE"                "mate-desktop mate-session-manager mate-terminal marco caja mate-panel" "x11" "X"
add "Графические среды" "GNOME"               "ubuntu-desktop" "x11" "X"
add "Графические среды" "LXQt (лёгкая)"       "lxqt" "x11" "X"
add "Графические среды" "dbus"                "dbus dbus-x11"
add "Графические среды" "xinit + xorg"        "xinit xserver-xorg xserver-xorg-core"
# ---------- Пакеты для XFCE ----------
add "Пакеты для XFCE" "xfce4-goodies (плагины)"       "xfce4-goodies" "x11"
add "Пакеты для XFCE" "Меню Whisker"                  "xfce4-whiskermenu-plugin" "x11"
add "Пакеты для XFCE" "Файлы: Thunar + архивы"        "thunar thunar-archive-plugin" "x11"
add "Пакеты для XFCE" "Mousepad, Ristretto"           "mousepad ristretto" "x11"
add "Пакеты для XFCE" "Диспетчер задач, скриншоты"    "xfce4-taskmanager xfce4-screenshooter" "x11"
add "Пакеты для XFCE" "xrandr (разрешение)"           "x11-xserver-utils" "x11"
# ---------- Композитор и темы ----------
add "Композитор и темы" "picom (внешний композитор)"  "picom" "x11"
add "Композитор и темы" "Тема Arc"                    "arc-theme" "x11"
add "Композитор и темы" "Иконки Papirus"              "papirus-icon-theme" "x11"
add "Композитор и темы" "Шрифты (Noto, fontconfig)"   "fontconfig fonts-noto"
# ---------- Языки ----------
add "Языки программирования" "Python 3"                     "python3 python3-pip python3-venv"
add "Языки программирования" "Rust (rustc + cargo)"         "rustc cargo"
add "Языки программирования" "JavaScript (Node.js + npm)"   "nodejs npm"
add "Языки программирования" "PHP"                          "php"
add "Языки программирования" "Ruby"                         "ruby"
add "Языки программирования" "C / C++ (gcc, clang, make)"   "gcc g++ make cmake clang"
add "Языки программирования" "C# (.NET / Mono)"             "dotnet-sdk-8.0/mono-complete"
add "Языки программирования" "Ассемблер (nasm + binutils)"  "nasm binutils"
add "Языки программирования" "HTML/CSS (nginx + tidy)"      "nginx tidy"
add "Языки программирования" "Go"                           "golang-go"
add "Языки программирования" "Java (OpenJDK 17)"            "openjdk-17-jdk"
# ---------- Пакеты и сервисы ----------
add "Пакеты и сервисы" "SSH-сервер (sshd)"                 "openssh-server"
add "Пакеты и сервисы" "git, curl, wget"                   "git curl wget"
add "Пакеты и сервисы" "htop, neofetch, mc, nano"          "htop neofetch mc nano"
add "Пакеты и сервисы" "jq, ripgrep, fd-find"              "jq ripgrep fd-find"
add "Пакеты и сервисы" "Docker"                            "@docker"
add "Пакеты и сервисы" "ufw (firewall)"                    "ufw"
# ---------- Виртуализация ----------
add "Виртуализация и эмуляция" "QEMU x86_64 (запуск ISO)" "qemu-system-x86 qemu-utils"
add "Виртуализация и эмуляция" "virt-manager (GUI)"       "virt-manager"
add "Виртуализация и эмуляция" "VirtualBox"               "virtualbox"
add "Виртуализация и эмуляция" "Wine (запуск .exe)"       "wine wine64 wine32"
add "Виртуализация и эмуляция" "Lutris (игровой центр)"   "lutris"
add "Виртуализация и эмуляция" "adb / fastboot"           "android-tools-adb android-tools-fastboot"
# ---------- Приложения ----------
add "Приложения" "Firefox"                           "firefox" "x11"
add "Приложения" "Chromium"                          "chromium-browser" "x11"
add "Приложения" "Telegram Desktop"                  "telegram-desktop" "x11"
add "Приложения" "VLC"                               "vlc" "x11"
add "Приложения" "GIMP"                              "gimp" "x11"
# ---------- Ввод и сеть ----------
add "Ввод и сеть" "Клавиатура/мышь в X11 (xdotool, xinput)" "xdotool xinput" "x11"
add "Ввод и сеть" "Wi-Fi (nmcli + iw)"                      "network-manager iw wireless-tools"
add "Ввод и сеть" "nmap (сканер сети)"                      "nmap"
add "Ввод и сеть" "net-tools, dnsutils, traceroute"         "net-tools dnsutils traceroute"
add "Ввод и сеть" "tcpdump, wireshark"                      "tcpdump wireshark"

# =====================================================================
#  Установка
# =====================================================================
pkg_ok(){ dpkg -s "$1" >/dev/null 2>&1; }

installed_tok(){
  local alts alt; IFS='/' read -ra alts <<<"$1"
  for alt in "${alts[@]}"; do pkg_ok "$alt" && return 0; done
  return 1
}
installed(){
  local p="$1" tok
  if [[ $p == @* ]]; then "chk_${p#@}"; return; fi
  for tok in $p; do installed_tok "$tok" || return 1; done
  return 0
}

declare -A AVAIL
repo_has(){
  local n="$1"
  [[ -n ${AVAIL[$n]} ]] && { [[ ${AVAIL[$n]} == 1 ]]; return; }
  if apt-cache show "$n" >/dev/null 2>&1; then
    AVAIL[$n]=1; return 0
  fi
  AVAIL[$n]=0; return 1
}
suggest(){
  local base="${1%%-*}" s
  s=$(apt-cache search "^$base" 2>/dev/null | head -5 | awk '{print $1}' | tr '\n' ' ')
  [ -n "$s" ] && echo "  ${C}похожие пакеты:${N} $s"
}

install_item(){
  local p="$1" r="$2" tok alts alt hit i fail=0
  if [[ $p == @* ]]; then "ins_${p#@}"; return $?; fi
  for tok in $p; do
    installed_tok "$tok" && continue
    IFS='/' read -ra alts <<<"$tok"
    hit=""
    for i in "${!alts[@]}"; do
      alt="${alts[$i]}"
      if repo_has "$alt"; then hit="$alt"; break; fi
      echo "${R}✗ такого пакета не существует: $alt${N}"
      (( i+1 < ${#alts[@]} )) && echo "  ищу альтернативу: ${alts[$((i+1))]}"
    done
    if [[ -z $hit ]]; then
      echo "${R}✗ «$tok» не был найден в репозиториях${N}"
      suggest "${alts[0]}"
      echo "$tok" >>"$FAILED"; fail=1; continue
    fi
    echo "${G}✓ найден в репозитории: $hit${N}"
    if ! job "Установка $hit" apt_get install -y "$hit"; then
      echo "$hit" >>"$FAILED"; fail=1
    fi
  done
  return $fail
}

menu_cat(){
  local cat="$1" idxs i c l p r f n sel k bad
  while true; do
    clear; echo "${B}${C}$cat${N}"; echo
    idxs=(); n=0
    for i in "${!ITEMS[@]}"; do
      IFS='|' read -r c l p r f <<<"${ITEMS[$i]}"
      [[ $c == "$cat" ]] || continue
      idxs+=("$i"); n=$((n+1))
      if installed "$p"; then printf " %2d) %s[✓]%s %s\n" "$n" "$G" "$N" "$l"
      else printf " %2d) %s[ ]%s %s\n" "$n" "$R" "$N" "$l"; fi
    done
    echo; echo " a) поставить всё недостающее    0) назад"
    read -rp "Номера через пробел: " sel
    case "$sel" in 0|"") return ;; a) sel=$(seq 1 "$n") ;; esac
    bad=0
    for k in $sel; do
      [[ $k =~ ^[0-9]+$ ]] && (( k>=1 && k<=n )) || continue
      IFS='|' read -r c l p r f <<<"${ITEMS[${idxs[$((k-1))]}]}"
      if installed "$p"; then echo "$l — уже есть"; continue; fi
      echo "${Y}→ $l${N}"
      if install_item "$p" "$r"; then echo "${G}готово${N}"; else echo "${R}ошибка${N}"; bad=1; fi
    done
    (( bad )) && echo && echo "${Y}Были ошибки — в главном меню пункт r (починка).${N}"
    pause
  done
}

# =====================================================================
#  Система / мощность / Wi-Fi
# =====================================================================
sysinfo(){
  clear; echo "${B}${C}Система${N}"
  . /etc/os-release 2>/dev/null
  echo "ОС         : ${PRETTY_NAME:-$(uname -s)}"
  echo "Ядро       : $(uname -r)"
  echo "Платформа  : $(uname -m)"
  echo "Хост       : $(hostnamectl --static 2>/dev/null || uname -n)"
  echo "Модель     : $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) $(cat /sys/class/dmi/id/product_name 2>/dev/null)"
  echo "Процессор  : $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
  echo "Ядра       : $(nproc)"
  echo "ОЗУ        : $(free -h | awk '/Mem:/{print $2" (свободно "$7")"}')"
  echo "Оболочка   : $(basename "${SHELL:-bash}")"
  command -v glxinfo >/dev/null && { echo "GL:"; glxinfo -B 2>/dev/null | sed -n '1,6p'; }
  pause
}

wifi_scan(){
  clear; echo "${B}${C}Wi-Fi сети рядом${N}"
  if command -v nmcli >/dev/null; then
    nmcli -f SSID,BSSID,SIGNAL,FREQ device wifi list 2>/dev/null
  elif command -v iw >/dev/null; then
    local ifc
    ifc=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
    [ -n "$ifc" ] && $SUDO iw dev "$ifc" scan 2>/dev/null | awk '/^BSS/{bss=$2} /SSID:/{ssid=substr($0,index($0,":")+2)} /signal:/{print ssid"\t"$2" dBm\t"bss}'
  else
    echo "Нужен nmcli (NetworkManager) или iw (категория «Ввод и сеть»)."
  fi
  pause
}

perf_check(){
  clear; echo "${B}${C}Проверка мощности${N}"; echo
  local cpu cores maxf ram_t ram_a swap disk s e speed kvm
  cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
  cores=$(nproc)
  maxf=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
  ram_t=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
  ram_a=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
  swap=$(awk '/SwapTotal/{print int($2/1024)}' /proc/meminfo)
  disk=$(df -h "$HOME" | awk 'NR==2{print $4}')
  [ -r /dev/kvm ] && kvm="есть" || kvm="нет (виртуалки будут медленными)"
  s=$(date +%s.%N); head -c 200000000 /dev/zero | sha256sum >/dev/null; e=$(date +%s.%N)
  speed=$(awk -v s="$s" -v e="$e" 'BEGIN{printf "%.0f", 200/(e-s)}')
  echo "Процессор  : $cpu"
  echo "Ядра       : $cores${maxf:+   (макс. $((maxf/1000)) МГц)}"
  echo "ОЗУ        : всего ${ram_t} МБ, свободно ${ram_a} МБ, swap ${swap} МБ"
  echo "Диск       : свободно $disk в \$HOME"
  echo "KVM        : $kvm"
  echo "Тест CPU   : ~${speed} МБ/с (sha256, 1 поток)"
  echo; echo "${B}Рекомендация:${N}"
  if (( ram_a < 1500 || cores < 4 )); then
    echo " XFCE/LXQt, композитор выключен, графика software (llvmpipe)."
  elif (( ram_a < 3000 )); then
    echo " XFCE или MATE. ISO в QEMU — только лёгкие системы."
  else
    echo " Потянет и Plasma, и GNOME; ISO в QEMU ~2 ГБ ОЗУ (лучше с KVM)."
  fi
  pause
}

# =====================================================================
#  Чёрные рамки / композитор (XFCE)
# =====================================================================
XFWM_XML="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml"
GTK_CSS="$HOME/.config/gtk-3.0/gtk.css"
PICOM_CONF="$HOME/.config/picom/picom.conf"
backup_once(){ [ -f "$1" ] && [ ! -f "$1.1t.bak" ] && ! grep -q 1t-setup "$1" && cp "$1" "$1.1t.bak"; return 0; }

write_xfwm(){
  mkdir -p "$(dirname "$XFWM_XML")"; backup_once "$XFWM_XML"
  cat >"$XFWM_XML" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!-- 1t-setup -->
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="$1"/>
    <property name="show_dock_shadow" type="bool" value="false"/>
    <property name="show_frame_shadow" type="bool" value="false"/>
    <property name="show_popup_shadow" type="bool" value="false"/>
    <property name="vblank_mode" type="string" value="off"/>
  </property>
</channel>
EOF
}

fix_borders(){
  local ans f
  while true; do
    clear; echo "${B}${C}Чёрные рамки у меню${N}  (режим композитора: $COMP)"; echo
    echo " Причина: без композитора прозрачные края меню рисуются чёрными."; echo
    echo " 1) GTK-стиль без теней и скруглений (дёшево, пробуй первым)"
    echo " 2) Встроенный композитор xfwm4, тени выключены"
    echo " 3) picom (xrender, без теней) вместо xfwm4"
    echo " 4) Вернуть всё как было"
    echo " 0) назад"
    read -rp "> " ans
    case "$ans" in
      1) mkdir -p "$(dirname "$GTK_CSS")"; backup_once "$GTK_CSS"
         cat >"$GTK_CSS" <<'EOF'
/* 1t-setup: без чёрных рамок вокруг меню */
decoration, .csd decoration, .popup decoration { box-shadow: none; margin: 0; border-radius: 0; }
window.csd, .csd { box-shadow: none; border-radius: 0; }
menu, .menu, .popup, tooltip.background { border-radius: 0; box-shadow: none; }
EOF
         echo "${G}Готово.${N} Перезапусти рабочий стол."; pause ;;
      2) write_xfwm true; COMP=xfwm; save_conf
         echo "${G}Готово.${N} Если тормозит — вариант 3 или 1."; pause ;;
      3) pkg_ok picom || install_item picom ""
         write_xfwm false
         mkdir -p "$(dirname "$PICOM_CONF")"
         printf '# 1t-setup\nbackend = "xrender";\nvsync = false;\nshadow = false;\nfading = false;\n' >"$PICOM_CONF"
         COMP=picom; save_conf
         echo "${G}Готово.${N} picom стартует вместе с рабочим столом."; pause ;;
      4) for f in "$XFWM_XML" "$GTK_CSS"; do
           if [ -f "$f.1t.bak" ]; then mv "$f.1t.bak" "$f"
           elif [ -f "$f" ] && grep -q 1t-setup "$f"; then rm -f "$f"; fi
         done
         rm -f "$PICOM_CONF"; COMP=none; save_conf; echo "Возвращено."; pause ;;
      0|"") return ;;
    esac
  done
}

# =====================================================================
#  Запуск рабочего стола
# =====================================================================
start_desktop(){
  local ans cmd
  echo "Среда: 1) xfce  2) plasma  3) mate  4) gnome   [сейчас: $DE, Enter = оставить]"
  read -rp "> " ans
  case "$ans" in 1) DE=xfce ;; 2) DE=plasma ;; 3) DE=mate ;; 4) DE=gnome ;; esac
  echo "Графика: 1) native  2) software  3) zink   [сейчас: $GPU]"
  read -rp "> " ans
  case "$ans" in 1) GPU=native ;; 2) GPU=software ;; 3) GPU=zink ;; esac
  save_conf
  case "$DE" in
    xfce)   cmd=startxfce4 ;;
    plasma) cmd=startplasma-x11 ;;
    mate)   cmd=mate-session ;;
    gnome)  cmd=gnome-session ;;
  esac
  command -v "$cmd" >/dev/null || { echo "${R}Нет $cmd — поставь в «Графические среды».${N}"; pause; return; }
  case "$GPU" in
    software) export GALLIUM_DRIVER=llvmpipe LIBGL_ALWAYS_SOFTWARE=1 ;;
    zink)     export MESA_LOADER_DRIVER_OVERRIDE=zink ;;
    native)   : ;;
  esac
  [ "$COMP" = picom ] && command -v picom >/dev/null && picom --config "$PICOM_CONF" -b
  echo "${G}Запускаю $DE ($GPU).${N}"
  if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    startx "$cmd"
  else
    "$cmd"
  fi
  pause
}

# =====================================================================
#  ISO / EXE / DEB
# =====================================================================
hsize(){ awk -v b="$1" 'BEGIN{split("B K M G T",u," "); i=1; while(b>=1024&&i<5){b/=1024;i++} f=(i==1?"%d %s":"%.1f %s"); printf f, b, u[i]}'; }

browse_files(){
  local ext="$1" dir items name i n page=0 per=10 first last sel all=0 args e _e p sz pages
  if   [ -d "$HOME/Downloads" ]; then dir="$HOME/Downloads"
  elif [ -d /mnt ]; then dir=/mnt
  elif [ -d /media ]; then dir=/media
  else dir="$HOME"; fi
  while true; do
    items=(); args=()
    if (( all )); then args=(-name '*')
    else IFS='|' read -ra _e <<<"$ext"; for e in "${_e[@]}"; do args+=(-o -iname "*.$e"); done; args=("${args[@]:1}"); fi
    while IFS= read -r -d '' name; do items+=("$name/"); done < <(find -L "$dir" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\0' 2>/dev/null | sort -z)
    while IFS= read -r -d '' name; do items+=("$name");  done < <(find -L "$dir" -mindepth 1 -maxdepth 1 -type f ! -name '.*' \( "${args[@]}" \) -printf '%f\0' 2>/dev/null | sort -z)
    n=${#items[@]}; pages=$(( (n+per-1)/per )); (( pages<1 )) && pages=1
    (( page >= pages )) && page=$((pages-1))
    clear; echo "${B}${C}Обзор: $dir${N}"
    (( all )) && echo "(показаны все файлы)" || echo "(показаны: ${ext//|/, })"; echo
    first=$(( page*per )); last=$(( first+per )); (( last>n )) && last=$n
    if (( n == 0 )); then
      echo "  (пусто)"; [ -r "$dir" ] || echo "  ${R}нет доступа${N}"
    fi
    for (( i=first; i<last; i++ )); do
      name="${items[$i]}"
      if [[ $name == */ ]]; then printf ' %2d) %s%s%s\n' $((i+1)) "$C" "$name" "$N"
      else sz=$(hsize "$(stat -c %s "$dir/$name" 2>/dev/null || echo 0)")
           printf ' %2d) %s%s%s  %s\n' $((i+1)) "$G" "$name" "$N" "$sz"; fi
    done
    echo; echo " стр. $((page+1))/$pages   n — дальше, b — назад"
    echo " u — вверх  h — \$HOME  r — /  a — все файлы  0 — отмена"
    echo " Номер — открыть/выбрать, либо впиши путь (/… или ~/…)"
    read -rp "> " sel
    case "$sel" in
      0|"") return 1 ;;
      u) dir=$(dirname "$dir"); page=0 ;;
      h) dir="$HOME"; page=0 ;;
      r) dir=/; page=0 ;;
      a) all=$((1-all)); page=0 ;;
      n) (( (page+1)*per < n )) && page=$((page+1)) ;;
      b) (( page > 0 )) && page=$((page-1)) ;;
      /*|~*) p="${sel/#\~/$HOME}"
             if [ -d "$p" ]; then dir="${p%/}"; [ -z "$dir" ] && dir=/; page=0
             elif [ -f "$p" ]; then PICKED="$p"; return 0
             else echo "Нет такого пути."; sleep 1; fi ;;
      *) if [[ $sel =~ ^[0-9]+$ ]] && (( sel>=1 && sel<=n )); then
           name="${items[$((sel-1))]}"
           if [[ $name == */ ]]; then dir="${dir%/}/${name%/}"; page=0
           else PICKED="${dir%/}/$name"; return 0; fi
         fi ;;
    esac
  done
}

system_pick(){   # $1 = ISO|EXE|DEB, $2 = "iso|img" фильтр
  local f ext="$2"
  if ! command -v zenity >/dev/null; then
    if ask_yn "Установить zenity для системного диалога выбора файла?"; then
      apt_get install -y zenity || return 1
    else
      return 1
    fi
  fi
  local filter; filter=$(IFS='|'; for e in $ext; do printf '*.%s ' "$e"; done)
  f=$(zenity --file-selection --title="Выбери $1" --file-filter="${filter}" 2>/dev/null) || return 1
  [ -f "$f" ] && PICKED="$f"
}

pick_file(){
  local ans; PICKED=""
  while true; do
    clear; echo "${B}${C}Выбор файла: $1${N}"; echo
    echo " 1) Системный диалог (zenity)"
    echo " 2) Обзор папок в консоли"
    echo " 3) Вписать путь вручную"
    echo " 0) отмена"
    read -rp "> " ans
    case "$ans" in
      1) system_pick "$1" "$2" && return 0 ;;
      2) browse_files "$2" && return 0 ;;
      3) read -erp "Путь к файлу: " PICKED
         PICKED="${PICKED//\"/}"; PICKED="${PICKED/#\~/$HOME}"
         [ -f "$PICKED" ] && return 0; echo "Файл не найден."; pause ;;
      0|"") return 1 ;;
    esac
  done
}

run_iso(){
  local iso disk size ram cores disp kvm
  command -v qemu-system-x86_64 >/dev/null || { echo "${R}Нет QEMU — поставь в «Виртуализация».${N}"; pause; return; }
  pick_file ISO 'iso|img' || return
  iso="$PICKED"; echo "Выбран: ${B}$iso${N}"
  mkdir -p "$HOME/vm"; disk="$HOME/vm/disk.qcow2"
  if [ ! -f "$disk" ]; then
    read -rp "Размер диска ГБ [16]: " size; size=${size:-16}
    job "Создание диска ${size} ГБ" qemu-img create -f qcow2 "$disk" "${size}G" || { pause; return; }
  fi
  ram=$(awk '/MemAvailable/{r=int($2/1024/2); if(r<1024)r=1024; if(r>4096)r=4096; print r}' /proc/meminfo)
  cores=$(( $(nproc) / 2 )); (( cores < 1 )) && cores=1
  [ -r /dev/kvm ] && kvm="-enable-kvm -cpu host" || kvm="-accel tcg,thread=multi -cpu qemu64"
  if [ -n "$DISPLAY" ]; then disp="-display gtk"; else disp="-display vnc=127.0.0.1:1"
    echo "Без X11 картинка по VNC: клиент на 127.0.0.1:5901"; fi
  echo "${Y}ОЗУ ${ram} МБ, ядер ${cores}.${N}"
  qemu-system-x86_64 -machine q35 $kvm -m "$ram" -smp "$cores" \
    -drive file="$disk",if=virtio -cdrom "$iso" -boot d \
    -vga std -device qemu-xhci -device usb-tablet \
    -nic user,model=virtio-net-pci $disp
  pause
}

run_exe(){
  local f
  pick_file EXE 'exe|msi|bat' || return
  f="$PICKED"; echo "Выбран: ${B}$f${N}"
  export DISPLAY="${DISPLAY:-:0}"
  if command -v wine >/dev/null; then echo "Запускаю через Wine…"; wine "$f"
  else echo "${R}Нет Wine — поставь в «Виртуализация».${N}"; fi
  pause
}

install_deb(){
  pick_file DEB 'deb' || return
  echo "Устанавливаю: ${B}$PICKED${N}"
  if $SUDO apt-get install -y "$PICKED"; then echo "${G}✓ готово${N}"
  elif $SUDO dpkg -i "$PICKED" && $SUDO apt-get -f install -y; then echo "${G}✓ готово${N}"
  else echo "${R}✗ не вышло, смотри лог${N}"; fi
  pause
}

vm_menu(){
  local ans
  while true; do
    clear; echo "${B}${C}ISO / EXE / DEB${N}"; echo
    echo " 1) Запустить ISO в QEMU (x86_64)"
    echo " 2) Запустить .exe (Wine)"
    echo " 3) Установить .deb пакет"
    echo " 0) назад"
    read -rp "> " ans
    case "$ans" in 1) run_iso ;; 2) run_exe ;; 3) install_deb ;; 0|"") return ;; esac
  done
}

# =====================================================================
#  ПОЧИНКА
# =====================================================================
ATT=(); CAUSES=(); _T=""
att(){ ATT+=("$1"); }

collect_logs(){
  local f
  { tail -n 80 "$LOG" 2>/dev/null
    for f in /var/log/apt/term.log /var/log/apt/history.log /var/log/dpkg.log; do
      [ -f "$f" ] && { echo "--- $f"; tail -n 60 "$f"; }
    done; } 2>/dev/null
}
_chk(){ grep -qiE "$1" <<<"$_T" && CAUSES+=("$2"); }

diagnose(){
  CAUSES=(); _T="$(collect_logs)"
  [ -n "$($SUDO dpkg --audit 2>&1)" ] && CAUSES+=("dpkg --audit: есть недоустановленные пакеты")
  $SUDO apt-get check >/dev/null 2>&1 || CAUSES+=("apt-get check: нарушены зависимости")
  [ -s "$FAILED" ] && CAUSES+=("не поставились: $(sort -u "$FAILED" | tr '\n' ' ')")
  _chk "dpkg was interrupted|dpkg --configure -a|half-configured|half-installed|not fully installed" "прерванная установка dpkg"
  _chk "unmet dependencies|held broken packages|Unable to correct problems" "сломанные зависимости"
  _chk "Could not get lock|Unable to lock|lock-frontend" "заблокирован dpkg/apt"
  _chk "Unable to locate package|has no installation candidate|is not available" "пакета нет в списках (устаревшие списки / не подключён репозиторий)"
  _chk "Failed to fetch|Temporary failure|Could not resolve|Connection timed out|Hash Sum mismatch|Err:[0-9]|404[[:space:]]+Not Found" "проблема сети или зеркала"
  _chk "NO_PUBKEY|not signed|GPG error|invalid signature|signatures were invalid|expired key" "проблема ключей репозитория"
  _chk "No space left on device" "закончилось место на диске"
  _chk "trying to overwrite|which is also in package" "конфликт файлов между пакетами"
  _chk "CANNOT LINK EXECUTABLE|cannot locate symbol|libc\+\+_shared" "несовместимые библиотеки"
  _chk "Permission denied" "нет прав на запись/доступ"
  df -P "$HOME" 2>/dev/null | awk 'NR==2{exit !($4<200000)}' && CAUSES+=("мало свободного места (<200 МБ)")
  return 0
}

pkg_health(){ [ -z "$($SUDO dpkg --audit 2>&1)" ] && $SUDO apt-get check >/dev/null 2>&1; }

retry_failed(){
  [ -s "$FAILED" ] || return 0
  local n ok=0
  for n in $(sort -u "$FAILED"); do
    echo "${Y}  повторная установка: $n${N}"
    job "Повторная установка $n" apt_get install -y "${n%%/*}" || ok=1
  done
  [ $ok = 0 ] && : >"$FAILED"
  return $ok
}

fx_locks(){
  if pgrep -x dpkg >/dev/null 2>&1 || pgrep -x apt >/dev/null 2>&1; then
    echo "Работает другой apt/dpkg — закрой его и повтори."; return 1
  fi
  $SUDO rm -f /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend \
                /var/cache/apt/archives/lock /var/lib/apt/lists/lock
  return 0
}
fx_dpkg(){ job "Достройка установок (dpkg --configure -a)" $SUDO dpkg --configure -a; }
fx_fixbroken(){
  apt_get --fix-broken install -y \
  || job "Починка зависимостей (force-overwrite)" apt_get -o Dpkg::Options::=--force-overwrite --fix-broken install -y
}
fx_update(){
  if ! $SUDO apt-get update; then
    if ask_yn "Обновление не прошло. Открыть «Программы и обновления»?"; then
      software-properties-gtk 2>/dev/null || software-properties-kde 2>/dev/null
    fi
    return 1
  fi
}
fx_keys(){ job "Ключи репозиториев" apt_get install -y ubuntu-keyring && $SUDO apt-get update; }
fx_clean(){ $SUDO apt clean; $SUDO rm -rf /var/lib/apt/lists/*; job "Обновление списков пакетов" apt_get update; }
fx_upgrade(){
  job "Полное обновление" apt-get -y -o APT::Status-Fd=3 \
    -o Dpkg::Options::=--force-overwrite -o Dpkg::Options::=--force-confnew dist-upgrade
}
fx_reinstall(){
  local n ok=0
  [ -s "$FAILED" ] || return 1
  for n in $(sort -u "$FAILED"); do
    job "Переустановка $n" apt_get install --reinstall -y "${n%%/*}" || ok=1
  done
  return $ok
}

repair_pkgs(){
  clear; echo "${B}${C}Починка пакетов${N}"; echo
  ATT=(); diagnose
  echo "${B}Анализ логов:${N}"
  if ((${#CAUSES[@]})); then printf ' • %s\n' "${CAUSES[@]}"; else echo " явных ошибок не найдено"; fi
  echo
  local list=(
    "Снять зависшие блокировки|fx_locks"
    "Достроить прерванные установки (dpkg --configure -a)|fx_dpkg"
    "Починить зависимости (apt --fix-broken)|fx_fixbroken"
    "Проверить сеть и обновить списки|fx_update"
    "Обновить ключи репозиториев|fx_keys"
    "Очистить кэш и списки пакетов|fx_clean"
    "Полное обновление (force-overwrite)|fx_upgrade"
    "Переустановить проблемные пакеты|fx_reinstall"
  )
  local item d f ok=0
  if pkg_health && retry_failed; then ok=1; echo "${G}dpkg и apt в порядке.${N}"; fi
  if (( ! ok )); then
    for item in "${list[@]}"; do
      d="${item%%|*}"; f="${item##*|}"
      echo "${Y}→ $d${N}"
      if "$f"; then att "$d: выполнено"; else att "$d: ошибка"; fi
      if pkg_health && retry_failed; then ok=1; break; fi
    done
  fi
  echo
  if (( ok )); then
    echo "${G}✓ Пакетная система в порядке.${N}"
  else
    echo "${R}✗ Автоматически починить не вышло. Формирую отчёт-промпт…${N}"; sleep 2
    make_report pkg ""
    return
  fi
  pause
}

# ---------- звук ----------
TONE="$STATE/tone.wav"; TL="$STATE/left.wav"; TR="$STATE/right.wav"
PCFG="$HOME/.config/pulse"

pa_running(){ pulseaudio --check 2>/dev/null || pgrep -x pipewire >/dev/null; }
pa_start(){
  if command -v pulseaudio >/dev/null; then
    pulseaudio -k 2>/dev/null; sleep 1
    pulseaudio --start --exit-idle-time=-1 --daemonize 2>>"$LOG"
  elif command -v pipewire >/dev/null; then
    systemctl --user restart pipewire pipewire-pulse 2>>"$LOG"
  fi
  sleep 1; pa_running
}
gen_tones(){
  pkg_ok sox || apt_get install -y sox
  [ -f "$TONE" ] || sox -n -c 2 -r 44100 "$TONE" synth 1.2 sine 440 2>/dev/null
  [ -f "$TL" ] || sox -n -c 2 -r 44100 "$TL" synth 1.2 sine 440 remix 1 0 2>/dev/null
  [ -f "$TR" ] || sox -n -c 2 -r 44100 "$TR" synth 1.2 sine 660 remix 0 1 2>/dev/null
}
play_wav(){ paplay "$1" 2>>"$LOG"; }
heard(){
  pa_running || pa_start
  echo "${C}Играю тон… (прибавь громкость)${N}"
  play_wav "$TONE"
  ask_yn "Звук слышно?"
}

a_restart(){ pa_start; }
a_unmute(){
  local s; s=$(pactl list short sinks 2>/dev/null | awk '$2!="stereo_both"{print $2; exit}')
  [ -n "$s" ] || return 1
  pactl set-default-sink "$s"; pactl set-sink-mute "$s" 0; pactl set-sink-volume "$s" 100%
  return 0
}
a_resetcfg(){
  local d
  for d in "$HOME/.config/pulse" "$HOME/.pulse"; do
    [ -d "$d" ] && mv "$d" "$d.1t.old.$(date +%s)"
  done
  pa_start
}
a_reinstall(){ run_logged apt-get install --reinstall -y pulseaudio && pa_start; }

repair_audio(){
  clear; echo "${B}${C}Починка звука${N}"; echo
  ATT=(); gen_tones
  pkg_ok pulseaudio || pkg_ok pipewire-pulse || job "Установка pulseaudio" apt_get install -y pulseaudio
  echo "Сначала проверим как есть."
  if heard; then echo "${G}Звук работает.${N}"; pause; return; fi
  att "Исходный тест: звука нет"
  local list=(
    "Перезапустить звуковой сервер|a_restart"
    "Снять mute, выставить громкость|a_unmute"
    "Сбросить конфиг PulseAudio|a_resetcfg"
    "Переустановить pulseaudio|a_reinstall"
  )
  local item d f ok=0
  for item in "${list[@]}"; do
    d="${item%%|*}"; f="${item##*|}"
    echo; echo "${Y}→ $d${N}"
    "$f" >>"$LOG" 2>&1 && att "$d: выполнено" || att "$d: ошибка"
    if heard; then ok=1; att "после «$d» звук появился"; break; fi
  done
  echo
  if (( ok )); then echo "${G}✓ Звук восстановлен.${N}"; pause; return; fi
  if ask_yn "Сформировать отчёт-промпт?"; then make_report audio ""; fi
}

test_lr(){
  pa_running || pa_start
  echo "Левый канал…";  play_wav "$TL"; sleep 0.3
  echo "Правый канал…"; play_wav "$TR"; sleep 0.3
  echo "Оба вместе…";   play_wav "$TONE"
  ask_yn "Играют ОБА динамика?"
}
cfg_stereo(){
  mkdir -p "$PCFG"
  [ -f "$PCFG/daemon.conf" ] && ! grep -q 1t-setup "$PCFG/daemon.conf" && cp "$PCFG/daemon.conf" "$PCFG/daemon.conf.1t.bak"
  cat >"$PCFG/daemon.conf" <<'EOF'
# 1t-setup
default-sample-channels = 2
default-channel-map = front-left,front-right
default-sample-rate = 48000
flat-volumes = no
EOF
  pa_start
}
cfg_remap(){
  local master
  pa_running || pa_start
  master=$(pactl list short sinks | awk '$2!="stereo_both"{print $2; exit}')
  [ -n "$master" ] || return 1
  mkdir -p "$PCFG"
  [ -f "$PCFG/default.pa" ] && ! grep -q 1t-setup "$PCFG/default.pa" && cp "$PCFG/default.pa" "$PCFG/default.pa.1t.bak"
  cat >"$PCFG/default.pa" <<EOF
# 1t-setup
.include /etc/pulse/default.pa
load-module module-remap-sink sink_name=stereo_both master=$master channels=2 channel_map=front-left,front-right master_channel_map=front-left,front-right remix=yes
set-default-sink stereo_both
EOF
  pa_start
}
reset_audio_cfg(){
  local f
  for f in "$PCFG/daemon.conf" "$PCFG/default.pa"; do
    if [ -f "$f.1t.bak" ]; then mv "$f.1t.bak" "$f"
    elif [ -f "$f" ] && grep -q 1t-setup "$f"; then rm -f "$f"; fi
  done
  pa_start; echo "Настройки звука 1t-setup сброшены."
}

audio_stereo(){
  clear; echo "${B}${C}Два динамика вместе${N}"; echo
  gen_tones
  pkg_ok pulseaudio || job "Установка pulseaudio" apt_get install -y pulseaudio
  ATT=()
  echo "Слушай: левый (низкий тон), правый (высокий), потом оба."
  if test_lr; then echo "${G}Оба динамика уже работают.${N}"; pause; return; fi
  att "Исходный тест: оба динамика не играют"
  echo; echo "${Y}→ Способ 1: принудительно стерео (2 канала) в PulseAudio${N}"
  cfg_stereo >>"$LOG" 2>&1; att "daemon.conf: стерео 2 канала, 48 кГц"
  if test_lr; then echo "${G}✓ Готово.${N}"; pause; return; fi
  echo; echo "${Y}→ Способ 2: виртуальный стерео-выход (remap-sink)${N}"
  cfg_remap >>"$LOG" 2>&1 && att "default.pa: remap-sink stereo_both" || att "remap-sink: ошибка"
  if test_lr; then echo "${G}✓ Готово.${N}"; pause; return; fi
  echo; echo "${Y}Из скрипта больше ничего не сделать — какие динамики получают звук, решает ALSA/прошивка.${N}"
  if ask_yn "Сбросить мои настройки звука обратно?"; then reset_audio_cfg; fi
  if ask_yn "Сформировать отчёт-промпт?"; then make_report audio "Оба динамика вместе не играют, играет один."; fi
}

# ---------- отчёт-промпт ----------
make_report(){
  local kind="$1" desc="$2"
  diagnose
  {
    echo "Ты — опытный помощник по Ubuntu (Linux). Разберись с проблемой ниже."
    echo "Нужно: 1) простыми словами объяснить, что произошло и почему;"
    echo "2) перечислить возможные причины от самой вероятной;"
    echo "3) дать пошаговый план починки с готовыми командами;"
    echo "4) сказать, как проверить, что всё починено."
    echo
    echo "=== ПРОБЛЕМА ==="
    case "$kind" in
      pkg)   echo "Не устанавливаются или сломаны пакеты (apt/dpkg)." ;;
      audio) echo "Нет звука (PulseAudio) и/или звук идёт только из одного динамика." ;;
      *)     echo "Другая проблема." ;;
    esac
    [ -n "$desc" ] && echo "Описание от пользователя: $desc"
    echo
    echo "=== ЧТО НАЙДЕНО АВТОМАТИЧЕСКИ ==="
    if ((${#CAUSES[@]})); then printf -- '- %s\n' "${CAUSES[@]}"; else echo "- явных ошибок в логах не найдено"; fi
    echo
    echo "=== ЧТО УЖЕ ПРОБОВАЛ СКРИПТ ==="
    if ((${#ATT[@]})); then printf -- '- %s\n' "${ATT[@]}"; else echo "- ничего"; fi
    echo
    echo "=== ОКРУЖЕНИЕ ==="
    . /etc/os-release 2>/dev/null
    echo "ОС: ${PRETTY_NAME:-unknown}, ядро $(uname -r), $(uname -m)"
    echo "Модель: $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) $(cat /sys/class/dmi/id/product_name 2>/dev/null)"
    echo "Свободно: $(( $(df -P "$HOME" | awk 'NR==2{print $4}') / 1024 )) МБ на \$HOME, $(( $(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo) )) МБ ОЗУ"
    echo
    if [ "$kind" = pkg ] || [ "$kind" = other ]; then
      echo "=== ПАКЕТНАЯ СИСТЕМА ==="
      echo "Не поставились: $(sort -u "$FAILED" 2>/dev/null | tr '\n' ' ')"
      echo "--- dpkg --audit"; $SUDO dpkg --audit 2>&1 | head -n 20
      echo "--- apt-get check"; $SUDO apt-get check 2>&1 | tail -n 10
      echo "--- sources"; cat /etc/apt/sources.list 2>/dev/null; cat /etc/apt/sources.list.d/* 2>/dev/null
      echo
    fi
    if [ "$kind" = audio ] || [ "$kind" = other ]; then
      echo "=== ЗВУК ==="
      echo "pulseaudio: $(pa_running && echo запущен || echo нет)"
      pactl info 2>&1 | head -n 15
      echo "--- sinks"; pactl list short sinks 2>&1
      echo "--- modules"; pactl list short modules 2>&1 | head -n 20
      echo "--- конфиги"; ls -la "$PCFG" 2>&1
      echo
    fi
    echo "=== ПОСЛЕДНИЕ СТРОКИ ЛОГА ==="
    tail -n 50 "$LOG"
  } >"$REPORT" 2>&1
  show_report
}

show_report(){
  [ -f "$REPORT" ] || { echo "Отчёта ещё нет."; pause; return; }
  clear
  { echo "${B}${R}▌ ОТЧЁТ-ПРОМПТ: скопируй целиком и отдай ИИ (q — выйти) ▐${N}"
    echo
    fold -s -w "${COLUMNS:-60}" "$REPORT"; } | { command -v less >/dev/null && less -R || cat; }
  echo; echo "Сохранён: $REPORT"
  if command -v xclip >/dev/null && ask_yn "Скопировать в буфер обмена?"; then
    xclip -selection clipboard <"$REPORT" && echo "Скопировано."
  fi
  pause
}

repair_other(){
  local desc
  clear; echo "${B}${C}Другая проблема${N}"; echo
  echo "Опиши её одной-двумя строками:"
  read -r desc
  ATT=(); att "Пользователь описал проблему вручную"
  make_report other "$desc"
}

repair_menu(){
  local ans
  while true; do
    clear; echo "${B}${C}Починка / восстановление${N}"; echo
    echo " 1) Пакеты: анализ логов и починка"
    echo " 2) Звук: починка"
    echo " 3) Звук: два динамика вместе"
    echo " 4) Другая проблема → отчёт-промпт"
    echo " 5) Показать последний отчёт"
    echo " 6) Сбросить мои настройки звука"
    echo " 0) назад"
    read -rp "> " ans
    case "$ans" in
      1) repair_pkgs ;; 2) repair_audio ;; 3) audio_stereo ;;
      4) repair_other ;; 5) show_report ;; 6) reset_audio_cfg; pause ;;
      0|"") return ;;
    esac
  done
}

# =====================================================================
#  Главное меню
# =====================================================================
main(){
  local i j c l p r f cat tot ok choice
  # первичное обновление списков, если /var/lib/apt/lists пуст
  if [ -z "$(ls -A /var/lib/apt/lists 2>/dev/null)" ]; then
    job "Обновление списков пакетов" apt_get update
  fi
  while true; do
    clear
    echo "${B}${C}=== 1t-setup (Ubuntu) ===${N}  [среда: $DE | графика: $GPU | композитор: $COMP]"; echo
    for i in "${!CATS[@]}"; do
      cat="${CATS[$i]}"; tot=0; ok=0
      for j in "${!ITEMS[@]}"; do
        IFS='|' read -r c l p r f <<<"${ITEMS[$j]}"
        [[ $c == "$cat" ]] || continue
        tot=$((tot+1)); installed "$p" && ok=$((ok+1))
      done
      printf " %2d) %-26s %s%d/%d%s\n" "$((i+1))" "$cat" "$Y" "$ok" "$tot" "$N"
    done
    echo
    echo " r) ПОЧИНКА    g) запустить рабочий стол   f) чёрные рамки"
    echo " p) мощность   s) инфо о системе   w) Wi-Fi   v) ISO/EXE/DEB"
    echo " u) обновить пакеты   q) выход"
    read -rp "> " choice
    case "$choice" in
      q|Q) exit 0 ;;
      r) repair_menu ;;
      g) start_desktop ;;
      f) fix_borders ;;
      p) perf_check ;;
      s) sysinfo ;;
      w) wifi_scan ;;
      v) vm_menu ;;
      u) job "Обновление списков пакетов" apt_get update && job "Обновление пакетов" apt_get -y full-upgrade; pause ;;
      *) if [[ $choice =~ ^[0-9]+$ ]] && (( choice>=1 && choice<=${#CATS[@]} )); then
           menu_cat "${CATS[$((choice-1))]}"
         fi ;;
    esac
  done
}

main