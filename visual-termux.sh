sed -i '/# XSAZ CD MENU/,$d' ~/.bashrc
sed -i '/# XSAZ TERMINAL PROMPT/,$d' ~/.bashrc

cat >> ~/.bashrc <<'EOF'
# XSAZ TERMINAL PROMPT
PS1='\[\e[1;36m\]╭─ XSAZ\[\e[0m\]@\[\e[1;32m\]ANDROID\[\e[0m\]\n\[\e[1;36m\]╰─ \[\e[1;33m\]\w\[\e[0m\] \[\e[1;35m\]➜\[\e[0m\] '
PS2='\[\e[1;35m\]   ➜ \[\e[0m\]'

# XSAZ CD MENU
xsaz_cd_menu() {
    local -a dirs
    local i=0 key seq target n

    while true; do
        dirs=(../ */)
        printf '\033[2J\033[H'
        printf '\033[1;36m╭─ XSAZ FILE NAVIGATOR\033[0m\n'
        printf '│ Путь: %s\n' "$PWD"
        printf '│ ↑ ↓ выбор | Enter открыть\n'
        printf '│ ← назад | → открыть | G перейти и выйти\n'
        printf '│ Esc отмена\n'
        printf '╰──────────────────────────\n\n'

        if ((${#dirs[@]} == 0)); then
            echo "Папок нет."
            read -rsn1 key
            [[ $key == $'\x1b' ]] && return
            continue
        fi

        (( i >= ${#dirs[@]} )) && i=$((${#dirs[@]} - 1))
        (( i < 0 )) && i=0

        for n in "${!dirs[@]}"; do
            if ((n == i)); then
                printf '\033[1;32m  ❯ %s\033[0m\n' "${dirs[n]}"
            else
                printf '    %s\n' "${dirs[n]}"
            fi
        done

        IFS= read -rsn1 key

        if [[ $key == $'\x1b' ]]; then
            IFS= read -rsn2 -t 0.2 seq
            case "$seq" in
                '[A') ((i > 0)) && ((i--)) ;;
                '[B') ((i < ${#dirs[@]} - 1)) && ((i++)) ;;
                '[C')
                    target=${dirs[i]}
                    [[ -d "$target" ]] && builtin cd -- "$target" && i=0
                    ;;
                '[D')
                    builtin cd .. && i=0
                    ;;
                *) return ;;
            esac
        elif [[ -z $key ]]; then
            target=${dirs[i]}
            [[ -d "$target" ]] && builtin cd -- "$target" && i=0
        elif [[ $key == [gG] ]]; then
            target=${dirs[i]}
            if [[ -d "$target" ]]; then
                builtin cd -- "$target" || continue
                printf '\033[2J\033[H'
                return
            fi
        elif [[ $key == [qQ] ]]; then
            return
        fi
    done
}

function cd() {
    if (($# == 0)); then
        xsaz_cd_menu
    else
        builtin cd "$@"
    fi
}

# XSAZ RUN MENU
xsaz_run_menu() {
    local -a items
    local i=0 key seq target n f rc c

    while true; do
        items=(../)
        for f in */; do [[ -d $f ]] && items+=("$f"); done
        for f in *.sh *.py *.js; do [[ -f $f ]] && items+=("$f"); done

        printf '\033[2J\033[H'
        printf '\033[1;36m╭─ XSAZ RUN MENU\033[0m\n'
        printf '│ Путь: %s\n' "$PWD"
        printf '│ ↑ ↓ выбор | →/Enter открыть папку | ← назад\n'
        printf '│ R запустить (.sh .py .js) | E править в nano\n'
        printf '│ G перейти в папку и выйти | Q/Esc выход\n'
        printf '╰──────────────────────────\n\n'

        (( i >= ${#items[@]} )) && i=$((${#items[@]} - 1))
        (( i < 0 )) && i=0

        for n in "${!items[@]}"; do
            case ${items[n]} in
                *.sh) c='1;33' ;;
                *.py) c='1;36' ;;
                *.js) c='1;35' ;;
                *)    c='1;34' ;;
            esac
            if ((n == i)); then
                printf '\033[1;32m  ❯ %s\033[0m\n' "${items[n]}"
            else
                printf '    \033[%sm%s\033[0m\n' "$c" "${items[n]}"
            fi
        done

        IFS= read -rsn1 key

        if [[ $key == $'\x1b' ]]; then
            IFS= read -rsn2 -t 0.2 seq
            case "$seq" in
                '[A') ((i > 0)) && ((i--)) ;;
                '[B') ((i < ${#items[@]} - 1)) && ((i++)) ;;
                '[C')
                    target=${items[i]}
                    [[ -d $target ]] && builtin cd -- "$target" && i=0
                    ;;
                '[D') builtin cd .. && i=0 ;;
                *) printf '\033[2J\033[H'; return ;;
            esac
        elif [[ -z $key ]]; then
            target=${items[i]}
            [[ -d $target ]] && builtin cd -- "$target" && i=0
        elif [[ $key == [rR] ]]; then
            target=${items[i]}
            if [[ -f $target ]]; then
                printf '\033[2J\033[H'
                printf '\033[1;36m▶ Запуск: %s\033[0m\n\n' "$target"
                rc=0
                case $target in
                    *.sh)
                        chmod +x -- "$target" 2>/dev/null
                        ./"$target"
                        rc=$?
                        if (( rc == 126 || rc == 127 )); then
                            printf '\n\033[1;33m↻ ./ не сработал, запускаю через bash...\033[0m\n\n'
                            bash "./$target"
                            rc=$?
                        fi
                        ;;
                    *.py)
                        if command -v python >/dev/null 2>&1; then
                            python "./$target"
                            rc=$?
                        else
                            printf 'python не установлен: apt install python\n'
                            rc=127
                        fi
                        ;;
                    *.js)
                        if command -v node >/dev/null 2>&1; then
                            node "./$target"
                            rc=$?
                        else
                            printf 'node не установлен: apt install nodejs\n'
                            rc=127
                        fi
                        ;;
                esac
                printf '\n\033[1;36m── Завершено (код %s). Нажми любую клавишу...\033[0m' "$rc"
                IFS= read -rsn1 _
            fi
        elif [[ $key == [eE] ]]; then
            target=${items[i]}
            if [[ -f $target ]]; then
                if command -v "${EDITOR:-nano}" >/dev/null 2>&1; then
                    "${EDITOR:-nano}" "$target"
                else
                    printf '\nРедактор не найден: apt install nano\nНажми любую клавишу...'
                    IFS= read -rsn1 _
                fi
            fi
        elif [[ $key == [gG] ]]; then
            target=${items[i]}
            if [[ -d $target ]]; then
                builtin cd -- "$target" || continue
                printf '\033[2J\033[H'
                return
            fi
        elif [[ $key == [qQ] ]]; then
            printf '\033[2J\033[H'
            return
        fi
    done
}

cd-run() {
    xsaz_run_menu
}

# XSAZ APT PROGRESS
xsaz_apt_run() {
    local sub=$1; shift
    local log=$HOME/.xsaz_last_install.log
    local st; st=$(mktemp) || return 1
    local -a args=() pkgs=()
    local a mon= start=$SECONDS dlw=50 pid rc line kind pct p=0 t=0 f j hd ph out
    local label='Подготовка' cols=${COLUMNS:-$(tput cols 2>/dev/null)} W
    local name noun end=а msg warns errs note

    if [[ $sub == reinstall ]]; then args=(install --reinstall); else args=("$sub"); fi
    [[ $sub == update ]] && dlw=100
    for a in "$@"; do
        args+=("$a")
        [[ $a != -* ]] && pkgs+=("${a##*/}")
    done

    W=$(( ${cols:-40} - 18 ))
    ((W > 40)) && W=40
    ((W < 10)) && W=10

    [[ $- == *m* ]] && mon=1
    set +m
    printf '\033[?25l'
    trap 'kill "$pid" 2>/dev/null; printf "\r\033[K\033[?25h\033[1;33m✖ Прервано\033[0m\n"; rm -f "$st"; [[ $mon ]] && set -m; trap - INT; return 130' INT

    DEBIAN_FRONTEND=noninteractive command apt-get -y \
        -o Dpkg::Options::=--force-confold -o APT::Status-Fd=3 \
        "${args[@]}" >"$log" 2>&1 3>"$st" </dev/null &
    pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        if ((t % 4 == 0)); then
            line=$(tail -n 1 "$st" 2>/dev/null)
            case $line in
                dlstatus:*|pmstatus:*)
                    IFS=: read -r kind _ pct _ <<<"$line"
                    pct=${pct%%.*}; pct=${pct//[^0-9]/}; pct=${pct:-0}
                    if [[ $kind == dlstatus ]]; then
                        pct=$((pct * dlw / 100)); label='Загрузка'
                    else
                        pct=$((50 + pct / 2)); label='Установка'
                    fi
                    ((pct > p)) && p=$pct
                    ;;
            esac
        fi

        f=$((p * W / 100))
        ph=$((t % 30))
        hd=-9
        ((ph < 9)) && hd=$((ph * (f + 3) / 8 - 1))
        out=
        for ((j = 0; j < W; j++)); do
            if ((j < f)); then
                if ((j >= hd - 1 && j <= hd + 1)); then
                    out+='\033[38;5;157m█'
                else
                    out+='\033[38;5;34m█'
                fi
            else
                out+='\033[38;5;238m░'
            fi
        done
        printf '\r  %b\033[0m %3d%% %s\033[K' "$out" "$p" "$label"
        t=$((t + 1))
        sleep 0.05
    done

    wait "$pid"; rc=$?
    trap - INT
    [[ $mon ]] && set -m
    printf '\r\033[K\033[?25h'
    rm -f "$st"

    if ((rc == 0)); then
        out=
        for ((j = 0; j < W; j++)); do out+='█'; done
        printf '  \033[38;5;34m%s\033[0m 100%%\n' "$out"
    fi

    name=${pkgs[*]}
    case $sub in
        install)   noun='Установка' ;;
        reinstall) noun='Переустановка' ;;
        update)    noun='Обновление списков'; end=о ;;
        *)         noun='Обновление пакетов'; end=о ;;
    esac
    msg="$noun${name:+ $name}"

    warns=$(grep -aiE '^W:|warning' "$log" | awk '!s[$0]++' | head -n 5)

    if ((rc == 0)); then
        printf '\033[1;32m✔ %s успешно завершен%s\033[0m\n' "$msg" "$end"
        if [[ -n $warns ]]; then
            printf '\033[1;33m⚠ Предупреждения:\033[0m\n'
            printf '%s\n' "$warns" | sed 's/^/  /'
            printf '\033[2m  Полный лог: %s\033[0m\n' "$log"
        fi
        note="$msg: готово"
    else
        printf '\033[1;31m✖ Ошибка: %s (код %s)\033[0m\n' "$msg" "$rc"
        errs=$(grep -aE '^E:|^Err:|^dpkg: error|error:|Error|Unable to|Could not|Failed|failed|No space' "$log" | awk '!s[$0]++' | head -n 8)
        [[ -z $errs ]] && errs=$(tail -n 6 "$log")
        printf '\033[0;31m'
        printf '%s\n' "$errs" | sed 's/^/  /'
        printf '\033[0m'
        if [[ -n $warns ]]; then
            printf '\033[1;33m⚠ Предупреждения:\033[0m\n'
            printf '%s\n' "$warns" | sed 's/^/  /'
        fi
        grep -qaE 'Unable to locate package|404' "$log" && printf '  Подсказка: сначала выполни apt update\n'
        grep -qaE 'Could not resolve|Temporary failure|Failed to connect' "$log" && printf '  Подсказка: проверь интернет\n'
        printf '\033[2m  Полный лог: %s\033[0m\n' "$log"
        note="$msg: ошибка"
    fi

    if (( SECONDS - start >= 10 )) && command -v termux-notification >/dev/null 2>&1; then
        ( termux-notification --title 'XSAZ' --content "$note" >/dev/null 2>&1 & )
    fi
    return $rc
}

apt() {
    case $1 in
        install|reinstall|upgrade|full-upgrade|update)
            if [[ -t 1 ]]; then xsaz_apt_run "$@"; else command apt "$@"; fi
            ;;
        *) command apt "$@" ;;
    esac
}

pkg() {
    case $1 in
        install|i|add) shift; apt install "$@" ;;
        reinstall)     shift; apt reinstall "$@" ;;
        update)        apt update ;;
        upgrade|up)    apt update && apt full-upgrade ;;
        *)             command pkg "$@" ;;
    esac
}

# XSAZ ALIASES
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias ..='builtin cd ..'
alias ...='builtin cd ../..'
alias up='pkg upgrade'
alias dl='cd ~/storage/downloads'
alias cls='clear'

# XSAZ GREETING
xsaz_greeting() {
    local j bat state free col

    if command -v termux-battery-status >/dev/null 2>&1; then
        j=$(timeout 2 termux-battery-status 2>/dev/null)
        bat=$(printf '%s' "$j" | grep -o '"percentage": *[0-9]*' | grep -o '[0-9]*$')
        state=$(printf '%s' "$j" | grep -o '"status": *"[A-Z_]*"' | grep -o '"[A-Z_]*"$' | tr -d '"')
    fi
    case $state in
        CHARGING) state=' (заряжается)' ;;
        FULL)     state=' (полная)' ;;
        *)        state='' ;;
    esac

    col='1;32'
    if [[ -n $bat ]]; then
        ((bat <= 50)) && col='1;33'
        ((bat <= 20)) && col='1;31'
    fi

    free=$(df -h "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')

    printf '\033[1;36m╭─ XSAZ\033[0m@\033[1;32mANDROID\033[0m\n'
    if [[ -n $bat ]]; then
        printf '\033[1;36m│\033[0m Заряд:    \033[%sm%s%%\033[0m%s\n' "$col" "$bat" "$state"
    fi
    printf '\033[1;36m│\033[0m Свободно: %s\n' "${free:-?}"
    printf '\033[1;36m│\033[0m Время:    %s\n' "$(date '+%d.%m.%Y %H:%M')"
    printf '\033[1;36m╰──────────────────────────\033[0m\n'
}

if [[ $- == *i* ]]; then
    xsaz_greeting
fi
EOF

source ~/.bashrc
