#!/data/data/com.termux/files/usr/bin/bash
# 1t-setup — всё в одном файле:
#   установка по категориям, графические среды, запуск рабочего стола,
#   проверка мощности, чёрные рамки меню, ISO/EXE/APK,
#   ПОЧИНКА (пакеты, звук, два динамика, отчёт-промпт).
# Запуск:  bash 1t-setup.sh

G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'

STATE="$HOME/.1t-setup"; mkdir -p "$STATE"
LOG="$STATE/install.log"; FAILED="$STATE/failed.list"; REPORT="$STATE/report.txt"
CONF="$STATE/config"
touch "$LOG" "$FAILED"
DE=xfce; GPU=software; COMP=none; TX11=no
[ -f "$CONF" ] && . "$CONF"
save_conf(){ printf 'DE=%s\nGPU=%s\nCOMP=%s\nTX11=%s\n' "$DE" "$GPU" "$COMP" "$TX11" >"$CONF"; }
pause(){ echo; read -rp "Enter..." _; }
ask_yn(){ local a; read -rp "$1 [y/N]: " a; [[ $a =~ ^([Yy]|[Yy][Ee][Ss]|[Дд]|[Дд][Аа])$ ]]; }
run_logged(){
  echo "=== $(date '+%F %T') $*" >>"$LOG"
  DEBIAN_FRONTEND=noninteractive "$@" 2>&1 | tee -a "$LOG"
  return "${PIPESTATUS[0]}"
}

CATS=("Видео и графика" "Звук" "Оболочки (shell)" "Графические среды" \
      "Пакеты для XFCE" "Композитор и темы" "Языки программирования" \
      "Пакеты и сервисы" "Виртуализация и эмуляция" "Приложения" "Ввод и сеть")

ITEMS=()
# add "Категория" "Название" "пакеты" "репо(x11|tur)" "флаг(X = графическая среда)"
#  пакеты: через пробел = нужны все; "a/b" = если нет a — пробуем b; "@имя" = особый пункт
add(){ ITEMS+=("$1|$2|$3|$4|$5"); }

# ---------- особые пункты ----------
chk_mobox(){ [ -d "$HOME/mobox" ]; }
ins_mobox(){
  pkg install -y curl || return 1
  curl -fL -o "$HOME/mobox_install" https://raw.githubusercontent.com/olegos2/mobox/main/install \
    && bash "$HOME/mobox_install"
}
chk_ohmyzsh(){ [ -d "$HOME/.oh-my-zsh" ]; }
ins_ohmyzsh(){
  pkg install -y git zsh || return 1
  git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh "$HOME/.oh-my-zsh" || return 1
  [ -f "$HOME/.zshrc" ] || cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
}
chk_zshdef(){ [ "$(readlink "$HOME/.termux/shell" 2>/dev/null)" = "$PREFIX/bin/zsh" ]; }
ins_zshdef(){ pkg install -y zsh && chsh -s zsh; }

# ---------- Видео и графика ----------
add "Видео и графика" "Mesa (OpenGL)"                    "mesa"
add "Видео и графика" "Turnip — Vulkan для Adreno"       "mesa-vulkan-icd-freedreno" "x11"
add "Видео и графика" "VirGL (рендер через Android GPU)" "virglrenderer-android" "x11"
add "Видео и графика" "Vulkan loader + vulkaninfo"       "vulkan-loader-android vulkan-tools"
add "Видео и графика" "mesa-demos (glxinfo, glxgears)"   "mesa-demos" "x11"
add "Видео и графика" "FFmpeg + mpv"                     "ffmpeg mpv"
# ---------- Звук ----------
add "Звук" "PulseAudio (сервер звука)"   "pulseaudio"
add "Звук" "Termux:API (CLI-часть)"      "termux-api"
add "Звук" "SoX + mpg123"                "sox mpg123"
add "Звук" "pavucontrol (микшер, GUI)"   "pavucontrol-qt" "x11"
add "Звук" "espeak (синтез речи)"        "espeak"
# ---------- Оболочки ----------
add "Оболочки (shell)" "bash"                          "bash"
add "Оболочки (shell)" "zsh"                           "zsh"
add "Оболочки (shell)" "Oh My Zsh"                     "@ohmyzsh"
add "Оболочки (shell)" "zsh как оболочка по умолчанию" "@zshdef"
add "Оболочки (shell)" "fish"                          "fish"
add "Оболочки (shell)" "tmux"                          "tmux"
add "Оболочки (shell)" "starship (красивый prompt)"    "starship"
# ---------- Графические среды ----------
add "Графические среды" "Termux-X11 (пакет)"  "termux-x11-nightly" "x11"
add "Графические среды" "XFCE"                "xfce4 xfce4-terminal" "x11" "X"
add "Графические среды" "KDE Plasma"          "plasma-desktop konsole dolphin" "x11" "X"
add "Графические среды" "MATE"                "mate-desktop mate-session-manager mate-terminal marco caja mate-panel" "x11" "X"
add "Графические среды" "dbus"                "dbus"
# ---------- Пакеты для XFCE ----------
add "Пакеты для XFCE" "xfce4-goodies (плагины)"       "xfce4-goodies" "x11"
add "Пакеты для XFCE" "Меню Whisker"                  "xfce4-whiskermenu-plugin" "x11"
add "Пакеты для XFCE" "Файлы: Thunar + архивы"        "thunar thunar-archive-plugin" "x11"
add "Пакеты для XFCE" "Mousepad, Ristretto"           "mousepad ristretto" "x11"
add "Пакеты для XFCE" "Диспетчер задач, скриншоты"    "xfce4-taskmanager xfce4-screenshooter" "x11"
add "Пакеты для XFCE" "xrandr (разрешение)"           "xorg-xrandr" "x11"
# ---------- Композитор и темы ----------
add "Композитор и темы" "picom (внешний композитор)"  "picom" "x11"
add "Композитор и темы" "Тема Arc"                    "arc-theme" "x11"
add "Композитор и темы" "Иконки Papirus"              "papirus-icon-theme" "x11"
add "Композитор и темы" "Шрифты (Noto, fontconfig)"   "fontconfig-utils noto-fonts"
# ---------- Языки ----------
add "Языки программирования" "Python"                      "python"
add "Языки программирования" "Rust"                        "rust"
add "Языки программирования" "JavaScript (Node.js + npm)"  "nodejs"
add "Языки программирования" "PHP"                         "php"
add "Языки программирования" "Ruby"                        "ruby"
add "Языки программирования" "C / C++ (clang)"             "clang make cmake"
add "Языки программирования" "C# (.NET / Mono)"            "dotnet8.0/dotnet9.0/mono" "tur"
add "Языки программирования" "Ассемблер (nasm + binutils)" "nasm binutils"
add "Языки программирования" "HTML/CSS (nginx + tidy)"     "nginx tidy"
add "Языки программирования" "Go"                          "golang"
add "Языки программирования" "Java (OpenJDK 17)"           "openjdk-17"
# ---------- Пакеты и сервисы ----------
add "Пакеты и сервисы" "Репозиторий x11-repo"              "x11-repo"
add "Пакеты и сервисы" "Репозиторий tur-repo"              "tur-repo"
add "Пакеты и сервисы" "SSH-сервер (sshd)"                 "openssh termux-services"
add "Пакеты и сервисы" "proot-distro (Debian/Ubuntu и др.)" "proot-distro"
add "Пакеты и сервисы" "git, curl, wget"                   "git curl wget"
add "Пакеты и сервисы" "htop, fastfetch, mc, nano"         "htop fastfetch mc nano"
# ---------- Виртуализация ----------
add "Виртуализация и эмуляция" "QEMU x86_64 (запуск ISO)" "qemu-system-x86-64 qemu-utils"
add "Виртуализация и эмуляция" "box64 (x86 на ARM)"       "box64" "tur"
add "Виртуализация и эмуляция" "Wine (запуск .exe)"       "hangover-wine/wine-stable" "tur"
add "Виртуализация и эмуляция" "Mobox"                    "@mobox"
add "Виртуализация и эмуляция" "adb (android-tools)"      "android-tools"
# ---------- Приложения ----------
add "Приложения" "Firefox"                           "firefox" "x11"
add "Приложения" "Chromium"                          "chromium" "tur"
add "Приложения" "Telegram Desktop"                  "telegram-desktop" "tur"
add "Приложения" "Minecraft (Prism Launcher + Java)" "prismlauncher openjdk-21" "tur"
add "Приложения" "VLC"                               "vlc" "x11"
# ---------- Ввод и сеть ----------
add "Ввод и сеть" "Клавиатура/мышь в X11 (xdotool, xinput)" "xdotool xorg-xinput" "x11"
add "Ввод и сеть" "Джойстик (evtest)"                       "evtest"
add "Ввод и сеть" "Wi-Fi сканер (termux-api + jq)"          "termux-api jq"
add "Ввод и сеть" "nmap (сканер сети)"                      "nmap"
add "Ввод и сеть" "iw, net-tools, dnsutils"                 "iw net-tools dnsutils"

# =====================================================================
#  Проверка репозиториев и установка
# =====================================================================
pkg_ok(){ dpkg -s "$1" >/dev/null 2>&1; }
net_ok(){   # проверка интернета по тому зеркалу, которое реально стоит в sources
  local u
  u=$(cat "$PREFIX"/etc/apt/sources.list "$PREFIX"/etc/apt/sources.list.d/* 2>/dev/null \
      | grep -oE 'https?://[^ ]+' | head -n1)
  curl -sI --max-time 8 "${u:-https://termux.net}" >/dev/null 2>&1
}

installed_tok(){   # токен вида a/b — установлен ли хоть один вариант
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

ensure_repo(){
  case "$1" in
    x11) pkg_ok x11-repo || { run_logged pkg install -y x11-repo && run_logged pkg update -y; } ;;
    tur) pkg_ok tur-repo || { run_logged pkg install -y tur-repo && run_logged pkg update -y; } ;;
  esac
}

declare -A AVAIL
repo_has(){   # 0 — пакет есть: сначала pkg search, потом apt search
  local n="$1"
  [[ -n ${AVAIL[$n]} ]] && { [[ ${AVAIL[$n]} == 1 ]]; return; }
  if pkg search "$n" 2>/dev/null | awk -F/ -v n="$n" '$1==n{f=1} END{exit !f}'; then
    AVAIL[$n]=1; return 0
  fi
  echo "${Y}  pkg search: «$n» не найден, пробую apt search…${N}"
  if apt search "$n" 2>/dev/null | awk -F/ -v n="$n" '$1==n{f=1} END{exit !f}'; then
    AVAIL[$n]=1; return 0
  fi
  AVAIL[$n]=0; return 1
}
suggest(){
  local base="${1%%-*}" s
  s=$(pkg search "$base" 2>/dev/null | awk -F/ 'NF>1 && $1 !~ / /{print $1}' | head -5 | tr '\n' ' ')
  [ -n "$s" ] && echo "  ${C}похожие пакеты:${N} $s"
}

install_item(){
  local p="$1" r="$2" tok alts alt hit i fail=0
  ensure_repo "$r"
  if [[ $p == @* ]]; then
    "ins_${p#@}" 2>&1 | tee -a "$LOG"; return "${PIPESTATUS[0]}"
  fi
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
    if ! run_logged pkg install -y "$hit"; then
      echo "${R}не удалось установить $hit${N}"; echo "$hit" >>"$FAILED"; fail=1
    fi
  done
  return $fail
}

ask_x11app(){
  [ "$TX11" = yes ] && return 0
  echo
  if ask_yn "Установлено ли приложение Termux:X11 на телефоне?"; then TX11=yes; save_conf; return 0; fi
  local apk url a
  case "$(uname -m)" in
    aarch64) apk="app-arm64-v8a-debug.apk" ;;
    armv7l|armv8l) apk="app-armeabi-v7a-debug.apk" ;;
    x86_64) apk="app-x86_64-debug.apk" ;;
    *) apk="app-universal-debug.apk" ;;
  esac
  url="https://github.com/termux/termux-x11/releases/tag/nightly"
  echo "${Y}Открываю релизы разработчика Termux:X11…${N}"
  echo "Скачай файл: ${B}$apk${N}  (нет такого — бери app-universal-debug.apk)"
  if command -v termux-open-url >/dev/null; then termux-open-url "$url"; else echo "Открой вручную: $url"; fi
  read -rp "Установил APK? Enter — продолжить, c — отмена: " a
  [[ $a == c ]] && return 1
  TX11=yes; save_conf; return 0
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
      if [[ $f == X ]]; then ask_x11app || { echo "пропущено"; continue; }; fi
      if install_item "$p" "$r"; then echo "${G}готово${N}"; else echo "${R}ошибка${N}"; bad=1; fi
    done
    (( bad )) && echo && echo "${Y}Были ошибки — в главном меню пункт r (починка) разберёт логи.${N}"
    pause
  done
}

# =====================================================================
#  Информация, мощность, Wi-Fi
# =====================================================================
sysinfo(){
  clear; echo "${B}${C}Система${N}"
  echo "Устройство : $(getprop ro.product.manufacturer) $(getprop ro.product.model)"
  echo "Платформа  : $(getprop ro.board.platform)   Архитектура: $(uname -m)"
  echo "Android    : $(getprop ro.build.version.release)"
  echo "Vulkan     : $(getprop ro.hardware.vulkan)   EGL: $(getprop ro.hardware.egl)"
  echo "Оболочка   : $(basename "${SHELL:-bash}")"
  echo
  echo "Adreno → Turnip (mesa-vulkan-icd-freedreno); Mali/PowerVR → VirGL."
  echo "Приложения Termux:X11 и Termux:API ставятся отдельно (APK)."
  pause
}

wifi_scan(){
  clear
  if ! command -v termux-wifi-scaninfo >/dev/null || ! command -v jq >/dev/null; then
    echo "Нужны termux-api и jq (категория «Ввод и сеть») и приложение Termux:API."
  else
    echo "${B}${C}Wi-Fi сети рядом${N} (нужна геолокация и права у Termux:API)"
    termux-wifi-scaninfo | jq -r '.[] | "\(.ssid)\t\(.rssi) dBm\t\(.frequency_mhz // .frequency) MHz\t\(.bssid)"' 2>/dev/null \
      | sort -t$'\t' -k2 -n -r | column -t -s$'\t' \
      || echo "Не вышло: проверь права и включена ли геолокация."
  fi
  pause
}

perf_check(){
  clear; echo "${B}${C}Проверка мощности${N}"; echo
  local soc cores maxf ram_t ram_a swap disk s e speed kvm
  soc="$(getprop ro.soc.manufacturer) $(getprop ro.soc.model)"
  [[ $soc == " " ]] && soc="$(getprop ro.board.platform)"
  cores=$(nproc)
  maxf=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
  ram_t=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
  ram_a=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
  swap=$(awk '/SwapTotal/{print int($2/1024)}' /proc/meminfo)
  disk=$(df -h "$HOME" | awk 'NR==2{print $4}')
  [ -r /dev/kvm ] && kvm="есть" || kvm="нет (виртуалки будут медленными)"
  s=$(date +%s.%N); head -c 200000000 /dev/zero | sha256sum >/dev/null; e=$(date +%s.%N)
  speed=$(awk -v s="$s" -v e="$e" 'BEGIN{printf "%.0f", 200/(e-s)}')
  echo "Чип        : $soc"
  echo "Ядра       : $cores${maxf:+   (макс. ${maxf%000} МГц)}"
  echo "ОЗУ        : всего ${ram_t} МБ, свободно ${ram_a} МБ, swap ${swap} МБ"
  echo "Место      : свободно $disk"
  echo "GPU/Vulkan : $(getprop ro.hardware.vulkan) / EGL $(getprop ro.hardware.egl)"
  echo "KVM        : $kvm"
  echo "Тест CPU   : ~${speed} МБ/с (sha256, 1 поток)"
  echo; echo "${B}Рекомендация:${N}"
  if (( ram_a < 1500 || cores < 4 )); then
    echo " XFCE, композитор выключен, графика software/virgl. Plasma не стоит."
  elif (( ram_a < 3000 )); then
    echo " XFCE или MATE; графика virgl или turnip. ISO в QEMU — только лёгкие системы."
  else
    echo " Потянет и Plasma, и XFCE; ISO в QEMU ~2 ГБ ОЗУ, но без KVM будет медленно."
  fi
  pause
}

# =====================================================================
#  Чёрные рамки / композитор
# =====================================================================
XFWM_XML="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml"
GTK_CSS="$HOME/.config/gtk-3.0/gtk.css"
PICOM_CONF="$HOME/.config/picom/picom.conf"
backup_once(){ [ -f "$1" ] && [ ! -f "$1.1t.bak" ] && ! grep -q 1t-setup "$1" && cp "$1" "$1.1t.bak"; return 0; }

write_xfwm(){   # $1 = true|false (композитор xfwm4)
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
      3) pkg_ok picom || install_item picom x11
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
  local ans cmd need
  ask_x11app || return
  echo "Среда: 1) xfce  2) plasma  3) mate   [сейчас: $DE, Enter = оставить]"; read -rp "> " ans
  case "$ans" in 1) DE=xfce ;; 2) DE=plasma ;; 3) DE=mate ;; esac
  echo "Графика: 1) software  2) virgl  3) turnip+zink   [сейчас: $GPU]"; read -rp "> " ans
  case "$ans" in 1) GPU=software ;; 2) GPU=virgl ;; 3) GPU=zink ;; esac
  save_conf
  case "$DE" in xfce) cmd=startxfce4 ;; plasma) cmd=startplasma-x11 ;; mate) cmd=mate-session ;; esac
  for need in termux-x11 "$cmd" dbus-launch; do
    command -v "$need" >/dev/null || { echo "${R}Нет $need — поставь в «Графические среды».${N}"; pause; return; }
  done
  pkill -f termux.x11 2>/dev/null; pkill virgl_test_server 2>/dev/null; pkill picom 2>/dev/null
  export XDG_RUNTIME_DIR="${TMPDIR:-$PREFIX/tmp}"
  termux-x11 :0 >/dev/null 2>&1 &
  sleep 3
  am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
  export DISPLAY=:0 PULSE_SERVER=127.0.0.1
  pulseaudio --check 2>/dev/null || pulseaudio --start --exit-idle-time=-1 --daemonize \
    --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1"
  case "$GPU" in
    virgl) virgl_test_server_android >/dev/null 2>&1 &
           sleep 1; export GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.0 ;;
    zink)  export MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform ;;
    *)     export GALLIUM_DRIVER=llvmpipe LIBGL_ALWAYS_SOFTWARE=1 ;;
  esac
  [ "$COMP" = picom ] && command -v picom >/dev/null && picom --config "$PICOM_CONF" -b
  echo "${G}Запускаю $DE ($GPU). Переключись в приложение Termux:X11.${N}"
  dbus-launch --exit-with-session "$cmd"
  pkill -f termux.x11 2>/dev/null; pkill virgl_test_server 2>/dev/null; pkill picom 2>/dev/null
  pause
}

# =====================================================================
#  ISO / EXE / APK
# =====================================================================
run_iso(){
  local iso disk size ram cores disp
  command -v qemu-system-x86_64 >/dev/null || { echo "${R}Нет QEMU — поставь в «Виртуализация».${N}"; pause; return; }
  read -rp "Путь к ISO: " iso
  [ -f "$iso" ] || { echo "Файл не найден."; pause; return; }
  mkdir -p "$HOME/vm"; disk="$HOME/vm/disk.qcow2"
  if [ ! -f "$disk" ]; then
    read -rp "Размер диска ГБ [16]: " size; size=${size:-16}
    qemu-img create -f qcow2 "$disk" "${size}G"
  fi
  ram=$(awk '/MemAvailable/{r=int($2/1024/2); if(r<1024)r=1024; if(r>4096)r=4096; print r}' /proc/meminfo)
  cores=$(( $(nproc) / 2 )); (( cores < 1 )) && cores=1
  if [ -n "$DISPLAY" ]; then disp="-display sdl"; else disp="-vnc 127.0.0.1:1"
    echo "Без X11 картинка по VNC: подключись клиентом к 127.0.0.1:5901"; fi
  echo "${Y}ОЗУ ${ram} МБ, ядер ${cores}. Без KVM будет медленно — это нормально.${N}"
  qemu-system-x86_64 -machine q35 -accel tcg,thread=multi -cpu qemu64 \
    -m "$ram" -smp "$cores" -drive file="$disk",if=virtio \
    -cdrom "$iso" -boot d -vga std -device qemu-xhci -device usb-tablet \
    -nic user,model=virtio-net-pci $disp
  pause
}
run_exe(){
  local f; read -rp "Путь к .exe: " f
  [ -f "$f" ] || { echo "Файл не найден."; pause; return; }
  export DISPLAY="${DISPLAY:-:0}"
  if command -v wine >/dev/null; then echo "Запускаю через Wine (нужен запущенный Termux:X11)…"; wine "$f"
  elif [ -d "$HOME/mobox" ]; then echo "Mobox установлен: запусти его по README проекта и открой этот файл там."
  else echo "${R}Нет ни Wine, ни Mobox — поставь в «Виртуализация».${N}"; fi
  pause
}
install_apk(){
  local f
  echo "${Y}Termux сам APK не запускает — это Linux-окружение, не Android.${N}"
  echo "Но можно открыть установщик Android (Termux должен иметь право ставить приложения)."
  read -rp "Путь к .apk: " f
  [ -f "$f" ] || { echo "Файл не найден."; pause; return; }
  command -v termux-open >/dev/null || pkg install -y termux-tools
  termux-open "$f"; pause
}
vm_menu(){
  local ans
  while true; do
    clear; echo "${B}${C}ISO / EXE / APK${N}"; echo
    echo " 1) Запустить ISO в QEMU (x86, может не заработать/тормозить)"
    echo " 2) Запустить .exe (Wine / Mobox)"
    echo " 3) Установить .apk в Android"
    echo " 0) назад"
    read -rp "> " ans
    case "$ans" in 1) run_iso ;; 2) run_exe ;; 3) install_apk ;; 0|"") return ;; esac
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
    for f in "$PREFIX/var/log/apt/term.log" "$PREFIX/var/log/apt/history.log" "$PREFIX/var/log/dpkg.log"; do
      [ -f "$f" ] && { echo "--- $f"; tail -n 60 "$f"; }
    done; } 2>/dev/null
}
_chk(){ grep -qiE "$1" <<<"$_T" && CAUSES+=("$2"); }

diagnose(){
  CAUSES=(); _T="$(collect_logs)"
  [ -n "$(dpkg --audit 2>&1)" ] && CAUSES+=("dpkg --audit: есть недоустановленные пакеты")
  apt-get check >/dev/null 2>&1 || CAUSES+=("apt-get check: нарушены зависимости")
  [ -s "$FAILED" ] && CAUSES+=("не поставились: $(sort -u "$FAILED" | tr '\n' ' ')")
  _chk "dpkg was interrupted|dpkg --configure -a|half-configured|half-installed|not fully installed" "прерванная установка dpkg (нужно dpkg --configure -a)"
  _chk "unmet dependencies|held broken packages|Unable to correct problems" "сломанные зависимости (apt --fix-broken)"
  _chk "Could not get lock|Unable to lock|lock-frontend" "заблокирован dpkg/apt (висит процесс или остался lock-файл)"
  _chk "Unable to locate package|has no installation candidate|is not available, but is referred" "пакета нет в списках: устаревшие списки или не подключён репозиторий (x11/tur)"
  _chk "Failed to fetch|Temporary failure|Could not resolve|Connection timed out|Hash Sum mismatch|Err:[0-9]|404[[:space:]]+Not Found" "проблема сети или зеркала (Failed to fetch / 404 / hash)"
  _chk "NO_PUBKEY|not signed|GPG error|invalid signature|signatures were invalid|expired key" "проблема ключей репозитория (termux-keyring)"
  _chk "No space left on device" "закончилось место на диске"
  _chk "trying to overwrite|which is also in package" "конфликт файлов между пакетами"
  _chk "CANNOT LINK EXECUTABLE|cannot locate symbol|libandroid-support|libc\+\+_shared" "несовместимые библиотеки (частичное обновление)"
  _chk "Permission denied" "нет прав на запись/доступ"
  df -P "$HOME" 2>/dev/null | awk 'NR==2{exit !($4<200000)}' && CAUSES+=("мало свободного места (<200 МБ)")
  return 0
}

pkg_health(){ [ -z "$(dpkg --audit 2>&1)" ] && apt-get check >/dev/null 2>&1; }

retry_failed(){
  [ -s "$FAILED" ] || return 0
  local n ok=0
  for n in $(sort -u "$FAILED"); do
    echo "${Y}  повторная установка: $n${N}"
    run_logged pkg install -y "${n%%/*}" || ok=1
  done
  [ $ok = 0 ] && : >"$FAILED"
  return $ok
}

fx_locks(){
  pgrep -x dpkg >/dev/null 2>&1 || pgrep -x apt >/dev/null 2>&1 && { echo "Работает другой apt/dpkg — закрой его и повтори."; return 1; }
  rm -f "$PREFIX/var/lib/dpkg/lock" "$PREFIX/var/lib/dpkg/lock-frontend" \
        "$PREFIX/var/cache/apt/archives/lock" "$PREFIX/var/lib/apt/lists/lock"
  return 0
}
fx_dpkg(){ run_logged dpkg --configure -a; }
fx_fixbroken(){
  run_logged apt --fix-broken install -y \
  || run_logged apt -o Dpkg::Options::="--force-overwrite" --fix-broken install -y
}
fx_update(){
  net_ok || echo "${R}Нет ответа от зеркала из sources — проверь интернет/VPN.${N}"
  run_logged pkg update -y && return 0
  if ask_yn "Обновление не прошло. Сменить зеркало (termux-change-repo)?"; then
    termux-change-repo && run_logged pkg update -y
  else return 1; fi
}
fx_keys(){ run_logged pkg install -y termux-keyring && run_logged pkg update -y; }
fx_clean(){ apt clean; rm -rf "$PREFIX"/var/lib/apt/lists/*; run_logged pkg update -y; }
fx_upgrade(){
  run_logged apt-get -y -o Dpkg::Options::="--force-overwrite" -o Dpkg::Options::="--force-confnew" dist-upgrade
}
fx_reinstall(){
  local n ok=0
  [ -s "$FAILED" ] || return 1
  for n in $(sort -u "$FAILED"); do run_logged apt-get install --reinstall -y "${n%%/*}" || ok=1; done
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

pa_running(){ pulseaudio --check 2>/dev/null; }
pa_start(){
  pulseaudio -k 2>/dev/null; sleep 1
  pulseaudio --start --exit-idle-time=-1 --daemonize \
    --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" 2>>"$LOG"
  sleep 1; pa_running
}
gen_tones(){
  pkg_ok sox || run_logged pkg install -y sox >/dev/null
  [ -f "$TONE" ] || sox -n -c 2 -r 44100 "$TONE" synth 1.2 sine 440 2>/dev/null
  [ -f "$TL" ] || sox -n -c 2 -r 44100 "$TL" synth 1.2 sine 440 remix 1 0 2>/dev/null
  [ -f "$TR" ] || sox -n -c 2 -r 44100 "$TR" synth 1.2 sine 660 remix 0 1 2>/dev/null
}
play_wav(){ paplay "$1" 2>>"$LOG"; }
heard(){
  pa_running || pa_start
  echo "${C}Играю тон… (прибавь громкость медиа на телефоне)${N}"
  play_wav "$TONE"
  ask_yn "Звук слышно?"
}

a_restart(){ pa_start; }
a_sink(){
  pa_running || pa_start
  [ -n "$(pactl list short sinks 2>/dev/null)" ] || pactl load-module module-sles-sink 2>>"$LOG"
  pactl list short sinks | grep -q . 
}
a_unmute(){
  local s; s=$(pactl list short sinks 2>/dev/null | awk '$2!="stereo_both"{print $2; exit}')
  [ -n "$s" ] || return 1
  pactl set-default-sink "$s"; pactl set-sink-mute "$s" 0; pactl set-sink-volume "$s" 100%
  if command -v termux-volume >/dev/null && command -v jq >/dev/null; then
    local mx; mx=$(termux-volume 2>/dev/null | jq -r '.[]|select(.stream=="music")|.max_volume' 2>/dev/null)
    [ -n "$mx" ] && termux-volume music $(( mx * 7 / 10 )) >/dev/null 2>&1
  fi
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
  pkg_ok pulseaudio || run_logged pkg install -y pulseaudio
  echo "Сначала проверим как есть."
  if heard; then echo "${G}Звук работает.${N}"; pause; return; fi
  att "Исходный тест: звука нет"
  local list=(
    "Перезапустить PulseAudio|a_restart"
    "Подключить звуковой выход OpenSL ES|a_sink"
    "Снять mute, выставить громкость и устройство по умолчанию|a_unmute"
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
  echo "${Y}Проверь на самом телефоне: громкость «Медиа», режим «Не беспокоить»,"
  echo "не подключены ли Bluetooth-наушники, не выключен ли звук в Termux:X11.${N}"
  if ask_yn "Звук всё равно не появился. Сформировать отчёт-промпт?"; then make_report audio ""; fi
}

test_lr(){
  pa_running || pa_start
  echo "Левый канал…";  play_wav "$TL"; sleep 0.3
  echo "Правый канал…"; play_wav "$TR"; sleep 0.3
  echo "Оба вместе…";   play_wav "$TONE"
  ask_yn "Играют ОБА динамика (верхний и нижний)?"
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
.include $PREFIX/etc/pulse/default.pa
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
  pkg_ok pulseaudio || run_logged pkg install -y pulseaudio
  ATT=()
  echo "Слушай: левый (низкий тон), правый (высокий), потом оба."
  if test_lr; then echo "${G}Оба динамика уже работают.${N}"; pause; return; fi
  att "Исходный тест: оба динамика вместе не играют"
  echo; echo "${Y}→ Способ 1: принудительно стерео (2 канала) в PulseAudio${N}"
  cfg_stereo >>"$LOG" 2>&1; att "daemon.conf: стерео 2 канала, 48 кГц"
  if test_lr; then echo "${G}✓ Готово, настройка сохранена.${N}"; pause; return; fi
  echo; echo "${Y}→ Способ 2: виртуальный стерео-выход с размножением моно на оба канала${N}"
  cfg_remap >>"$LOG" 2>&1 && att "default.pa: remap-sink stereo_both (remix)" || att "remap-sink: ошибка"
  if test_lr; then echo "${G}✓ Готово, настройка сохранена.${N}"; pause; return; fi
  echo
  echo "${Y}Из Termux больше ничего не сделать: какие динамики получают звук, решает Android"
  echo "и прошивка (на некоторых телефонах стерео включается только в системном плеере/по Dolby).${N}"
  if ask_yn "Сбросить мои настройки звука обратно?"; then reset_audio_cfg; fi
  if ask_yn "Сформировать отчёт-промпт?"; then make_report audio "Оба динамика вместе не играют, играет один."; fi
}

# ---------- отчёт-промпт ----------
make_report(){   # $1 = pkg|audio|other   $2 = описание от пользователя
  local kind="$1" desc="$2"
  diagnose
  {
    echo "Ты — опытный помощник по Termux (Android, Linux-терминал без root). Разберись с проблемой ниже."
    echo "Нужно: 1) простыми словами объяснить, что произошло и почему;"
    echo "2) перечислить возможные причины от самой вероятной;"
    echo "3) дать пошаговый план починки с готовыми командами;"
    echo "4) сказать, как проверить, что всё починено."
    echo
    echo "=== ПРОБЛЕМА ==="
    case "$kind" in
      pkg)   echo "Не устанавливаются или сломаны пакеты Termux (pkg/apt/dpkg)." ;;
      audio) echo "В Termux нет звука (PulseAudio) и/или звук идёт только из одного динамика." ;;
      *)     echo "Другая проблема." ;;
    esac
    [ -n "$desc" ] && echo "Описание от пользователя: $desc"
    echo
    echo "=== ЧТО НАЙДЕНО АВТОМАТИЧЕСКИ (возможные причины) ==="
    if ((${#CAUSES[@]})); then printf -- '- %s\n' "${CAUSES[@]}"; else echo "- явных ошибок в логах не найдено"; fi
    echo
    echo "=== ЧТО УЖЕ ПРОБОВАЛ СКРИПТ ==="
    if ((${#ATT[@]})); then printf -- '- %s\n' "${ATT[@]}"; else echo "- ничего (отчёт запрошен вручную)"; fi
    echo
    echo "=== ОКРУЖЕНИЕ ==="
    echo "Устройство: $(getprop ro.product.manufacturer) $(getprop ro.product.model), Android $(getprop ro.build.version.release), $(uname -m)"
    command -v termux-info >/dev/null && termux-info 2>/dev/null | head -n 25
    echo "Свободное место: $(df -h "$HOME" | awk 'NR==2{print $4}')   ОЗУ свободно: $(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo) МБ"
    echo "Интернет (зеркало из sources): $(net_ok && echo ok || echo НЕТ ответа)"
    echo
    if [ "$kind" = pkg ] || [ "$kind" = other ]; then
      echo "=== ПАКЕТНАЯ СИСТЕМА ==="
      echo "Не поставились: $(sort -u "$FAILED" 2>/dev/null | tr '\n' ' ')"
      echo "--- dpkg --audit"; dpkg --audit 2>&1 | head -n 20
      echo "--- apt-get check"; apt-get check 2>&1 | tail -n 10
      echo "--- sources"; cat "$PREFIX/etc/apt/sources.list" 2>/dev/null; cat "$PREFIX"/etc/apt/sources.list.d/* 2>/dev/null
      echo
    fi
    if [ "$kind" = audio ] || [ "$kind" = other ]; then
      echo "=== ЗВУК ==="
      echo "pulseaudio запущен: $(pa_running && echo да || echo нет)"
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
  { echo "${B}${R}▌ ОТЧЁТ-ПРОМПТ: скопируй целиком и отдай ИИ или разбирайся сам (q — выйти) ▐${N}"
    echo
    fold -s -w "${COLUMNS:-60}" "$REPORT"; } | { command -v less >/dev/null && less -R || cat; }
  echo; echo "Сохранён: $REPORT"
  if command -v termux-clipboard-set >/dev/null && ask_yn "Скопировать в буфер обмена?"; then
    termux-clipboard-set <"$REPORT" && echo "Скопировано."
  fi
  pause
}

repair_other(){
  local desc
  clear; echo "${B}${C}Другая проблема${N}"; echo
  echo "Опиши её одной-двумя строками (что не работает, что делал перед этим):"
  read -r desc
  ATT=(); att "Пользователь описал проблему вручную; автопочинка для неё не предусмотрена"
  make_report other "$desc"
}

repair_menu(){
  local ans
  while true; do
    clear; echo "${B}${C}Починка / восстановление${N}"; echo
    echo " 1) Пакеты: анализ логов и починка"
    echo " 2) Звук: починка (проверка «слышно / нет»)"
    echo " 3) Звук: два динамика вместе"
    echo " 4) Другая проблема → отчёт-промпт на весь экран"
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
  compgen -G "$PREFIX/var/lib/apt/lists/*Packages*" >/dev/null || { echo "Обновляю списки пакетов…"; pkg update -y; }
  while true; do
    clear
    echo "${B}${C}=== 1t-setup ===${N}  [среда: $DE | графика: $GPU | композитор: $COMP]"; echo
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
    echo " p) мощность   s) инфо о системе   w) Wi-Fi   v) ISO/EXE/APK"
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
      u) run_logged pkg update -y && run_logged pkg upgrade -y; pause ;;
      *) if [[ $choice =~ ^[0-9]+$ ]] && (( choice>=1 && choice<=${#CATS[@]} )); then
           menu_cat "${CATS[$((choice-1))]}"
         fi ;;
    esac
  done
}

main

