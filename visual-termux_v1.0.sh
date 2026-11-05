sed -i '/# XSAZ CD MENU/,$d' ~/.bashrc
sed -i '/# XSAZ TERMINAL PROMPT/,$d' ~/.bashrc

cat >> ~/.bashrc <<'EOF'
# XSAZ TERMINAL PROMPT
# ===================== ТЕМА (настройки в ~/.xsaz_theme, меню: theme) =====================
XT_CFG=$HOME/.xsaz_theme
declare -A XT_INST XT_MARK
declare -a XT_CUR XT_ITEMS XT_HDR
XT_RAINBOW=(196 202 208 214 220 226 190 154 118 82 46 48 51 45 39 33 27 21 57 93 129 165 201 199)

xt_defaults() {
    XT_BAR=34 XT_SHINE=157 XT_EMPTY=238
    XT_FULL='█' XT_VOID='░'
    XT_ANIM=shine
    XT_FRAME=rounded
    XT_GREET=box
    XT_ACCENT=6 XT_ACCENT2=2
    XT_USER=XSAZ XT_HOST=ANDROID
}

xt_colors() {
    C_A=$'\033[1;38;5;'"$XT_ACCENT"'m'
    C_B=$'\033[1;38;5;'"$XT_ACCENT2"'m'
    C_R=$'\033[0m'
}

xt_frame() {
    case $XT_FRAME in
        sharp)  F_TL='┌' F_BL='└' F_V='│' F_H='─' ;;
        double) F_TL='╔' F_BL='╚' F_V='║' F_H='═' ;;
        heavy)  F_TL='┏' F_BL='┗' F_V='┃' F_H='━' ;;
        ascii)  F_TL='+' F_BL='+' F_V='|' F_H='-' ;;
        *)      F_TL='╭' F_BL='╰' F_V='│' F_H='─' ;;
    esac
}

xt_load() {
    xt_defaults
    [[ -f $XT_CFG ]] && source "$XT_CFG" 2>/dev/null
    xt_colors
    xt_frame
}

xt_save() {
    local v
    for v in XT_BAR XT_SHINE XT_EMPTY XT_FULL XT_VOID XT_ANIM XT_FRAME XT_GREET XT_ACCENT XT_ACCENT2 XT_USER XT_HOST; do
        printf '%s=%q\n' "$v" "${!v}"
    done > "$XT_CFG"
}

xt_cls() { printf '\033[2J\033[H'; }
xt_sw()  { printf '\033[38;5;%sm███\033[0m' "$1"; }
xt_rule() { local s; printf -v s '%*s' "$1" ''; printf '%s' "${s// /$F_H}"; }

xsaz_set_prompt() {
    PS1="\[${C_A}\]${F_TL}${F_H} ${XT_USER}\[${C_R}\]@\[${C_B}\]${XT_HOST}\[${C_R}\]\n\[${C_A}\]${F_BL}${F_H} \[\e[1;33m\]\w\[${C_R}\] \[\e[1;35m\]➜\[${C_R}\] "
    PS2="\[\e[1;35m\]   ➜ \[${C_R}\]"
}

xt_refresh() { xt_colors; xt_frame; xsaz_set_prompt; }

# ---- прогресс-бар: XT_BAROUT = строка бара (W ширина, p процент, t кадр) ----
xt_render_bar() {
    local W=$1 p=$2 t=$3 f j col out= pos n=${#XT_RAINBOW[@]}
    f=$((p * W / 100))
    # блик всегда едет только вперёд и после конца бара начинает заново
    pos=$(( (t / 2) % (W + 12) - 3 ))
    for ((j = 0; j < W; j++)); do
        if ((j < f)); then
            col=$XT_BAR
            case $XT_ANIM in
                shine)   ((j >= pos - 1 && j <= pos + 1)) && col=$XT_SHINE ;;
                pulse)   (( (t / 8) % 2 )) && col=$XT_SHINE ;;
                rainbow) col=${XT_RAINBOW[(j + t / 2) % n]} ;;
                stripes) (( (j + t / 3) % 4 < 2 )) && col=$XT_SHINE ;;
            esac
            out+=$'\033[38;5;'"$col"'m'"$XT_FULL"
        else
            out+=$'\033[38;5;'"$XT_EMPTY"'m'"$XT_VOID"
        fi
    done
    XT_BAROUT=$out$'\033[0m'
}

# ---- универсальное меню со стрелками ----
# Вход: XT_HDR, XT_ITEMS, XT_FOOT, XT_IDX. Выход: XT_IDX, XT_KEY (enter right left esc q или символ)
xt_menu() {
    local rows top=0 n s key seq ex total lines cols
    while true; do
        total=${#XT_ITEMS[@]}
        ((total == 0)) && { XT_KEY=q; return 0; }
        lines=$(tput lines 2>/dev/null); lines=${lines:-24}
        cols=$(tput cols 2>/dev/null);  cols=${cols:-40}
        rows=$((lines - ${#XT_HDR[@]} - 3))
        ((rows < 3)) && rows=3
        ((XT_IDX >= total)) && XT_IDX=$((total - 1))
        ((XT_IDX < 0)) && XT_IDX=0
        ((XT_IDX < top)) && top=$XT_IDX
        ((XT_IDX >= top + rows)) && top=$((XT_IDX - rows + 1))

        printf '\033[H'
        for n in "${!XT_HDR[@]}"; do printf '%s\033[K\n' "${XT_HDR[n]}"; done
        for ((n = top; n < top + rows && n < total; n++)); do
            s=${XT_ITEMS[n]}
            [[ $s != *$'\033'* ]] && s=${s:0:cols-6}
            if ((n == XT_IDX)); then
                printf '\033[1;32m  ❯ \033[0;1m%s\033[0m\033[K\n' "$s"
            else
                printf '    %s\033[K\n' "$s"
            fi
        done
        printf '\033[2m %d/%d  %s\033[0m\033[K\n\033[J' $((XT_IDX + 1)) "$total" "$XT_FOOT"

        IFS= read -rsn1 key
        case $key in
            $'\033')
                IFS= read -rsn2 -t 0.1 seq
                case $seq in
                    '[A') ((XT_IDX > 0)) && ((XT_IDX--)) ;;
                    '[B') ((XT_IDX < total - 1)) && ((XT_IDX++)) ;;
                    '[C') XT_KEY=right; return 0 ;;
                    '[D') XT_KEY=left; return 0 ;;
                    '[5') IFS= read -rsn1 -t 0.1 ex; XT_IDX=$((XT_IDX - rows)) ;;
                    '[6') IFS= read -rsn1 -t 0.1 ex; XT_IDX=$((XT_IDX + rows)) ;;
                    '[H') XT_IDX=0 ;;
                    '[F') XT_IDX=$((total - 1)) ;;
                    '')   XT_KEY=esc; return 0 ;;
                esac
                ;;
            '') XT_KEY=enter; return 0 ;;
            *)  XT_KEY=${key,,}; return 0 ;;
        esac
    done
}

# шапка: xt_hdr "Заголовок" "строка1" "строка2"...
xt_hdr() {
    local l
    XT_HDR=("${C_A}${F_TL}${F_H} $1${C_R}")
    shift
    for l in "$@"; do XT_HDR+=("${F_V} $l"); done
    XT_HDR+=("${F_BL}$(xt_rule 26)")
}

# выбор из списка: xt_choose "Заголовок" ПЕРЕМЕННАЯ "значение|описание" ...
xt_choose() {
    local title=$1 var=$2 e i=0 cur=0
    local -a vals=()
    shift 2
    XT_ITEMS=()
    for e in "$@"; do
        vals+=("${e%%|*}")
        [[ ${e%%|*} == "${!var}" ]] && cur=$i
        XT_ITEMS+=("${e#*|}")
        ((i++))
    done
    xt_hdr "$title" "↑↓ выбор | Enter применить" "Q/Esc отмена"
    XT_FOOT=''
    XT_IDX=$cur
    xt_cls
    while true; do
        xt_menu
        case $XT_KEY in
            enter|right|e) printf -v "$var" '%s' "${vals[XT_IDX]}"; return 0 ;;
            q|esc|left) return 1 ;;
        esac
    done
}

# выбор цвета -> XT_COLOR
xt_pick_color() {
    local e num i=0
    local -a pal=("Зелёный:34" "Салатовый:118" "Светло-зелёный:157" "Мятный:48" "Бирюзовый:44" "Голубой:39"
        "Светло-голубой:117" "Синий:27" "Фиолетовый:93" "Пурпурный:165" "Розовый:205" "Светло-розовый:218"
        "Красный:196" "Оранжевый:208" "Жёлтый:220" "Белый:255" "Серый:245")
    XT_ITEMS=()
    for e in "${pal[@]}"; do XT_ITEMS+=("$(xt_sw "${e##*:}") ${e%%:*}"); done
    XT_ITEMS+=("Свой номер (0-255)…")
    xt_hdr "$1" "↑↓ выбор | Enter применить" "Q/Esc отмена"
    XT_FOOT=''
    XT_IDX=0
    xt_cls
    while true; do
        xt_menu
        case $XT_KEY in
            enter|right|e)
                if ((XT_IDX == ${#pal[@]})); then
                    xt_cls
                    read -erp 'Номер цвета 0-255: ' num
                    if [[ $num =~ ^[0-9]+$ ]] && ((num <= 255)); then XT_COLOR=$num; return 0; fi
                    xt_cls
                else
                    XT_COLOR=${pal[XT_IDX]##*:}; return 0
                fi
                ;;
            q|esc|left) return 1 ;;
        esac
    done
}

# выбор шрифта Termux (~/.termux/font.ttf)
xsaz_font_menu() {
    local -a files=() acts=()
    local d f p src ok fdir=$HOME/.termux
    mkdir -p "$fdir"
    mapfile -t files < <(
        for d in "$fdir/fonts" "$HOME/storage/downloads" "$HOME/storage/shared/Fonts" "$PWD"; do
            [[ -d $d ]] && find -L "$d" -maxdepth 2 -type f \( -iname '*.ttf' -o -iname '*.otf' \) 2>/dev/null
        done | awk '!s[$0]++'
    )
    acts=(default); XT_ITEMS=("Стандартный шрифт Termux")
    if [[ -f $fdir/font.ttf.prev ]]; then acts+=(prev); XT_ITEMS+=("Вернуть предыдущий шрифт"); fi
    for f in "${files[@]}"; do
        acts+=("file:$f")
        d=${f%/*}
        XT_ITEMS+=("${f##*/}  (${d/#$HOME/~})")
    done
    acts+=(manual); XT_ITEMS+=("Указать путь вручную…")
    xt_hdr "ШРИФТ TERMUX" "Enter применить | Q/Esc назад" "Ищу .ttf/.otf: Загрузки, ~/.termux/fonts, тут"
    XT_FOOT=''
    [[ -d $HOME/storage ]] || XT_FOOT='нет доступа к памяти: termux-setup-storage'
    XT_IDX=0
    xt_cls
    while true; do
        xt_menu
        case $XT_KEY in
            q|esc|left) return 0 ;;
            enter|right|e)
                src= ok=
                case ${acts[XT_IDX]} in
                    default)
                        [[ -f $fdir/font.ttf ]] && cp -f "$fdir/font.ttf" "$fdir/font.ttf.prev"
                        rm -f "$fdir/font.ttf"; ok=1 ;;
                    prev)
                        cp -f "$fdir/font.ttf.prev" "$fdir/font.ttf" && ok=1 ;;
                    manual)
                        xt_cls
                        read -erp 'Путь к .ttf/.otf: ' p
                        p=${p/#\~/$HOME}
                        [[ -f $p ]] && src=$p ;;
                    file:*) src=${acts[XT_IDX]#file:} ;;
                esac
                if [[ -n $src ]]; then
                    [[ -f $fdir/font.ttf ]] && cp -f "$fdir/font.ttf" "$fdir/font.ttf.prev"
                    cp -f -- "$src" "$fdir/font.ttf" && ok=1
                fi
                if [[ -n $ok ]]; then
                    command -v termux-reload-settings >/dev/null 2>&1 && termux-reload-settings
                    xt_cls
                    printf '\033[1;32m✔ Шрифт применён\033[0m\n(если не изменился — перезапусти Termux)\n\nНажми любую клавишу…'
                else
                    xt_cls
                    printf '\033[1;31m✖ Файл не найден\033[0m\n\nНажми любую клавишу…'
                fi
                IFS= read -rsn1 _
                return 0
                ;;
        esac
    done
}

# предпросмотр: приветствие + анимация бара
xt_preview() {
    local t p W=30
    xt_cls
    xsaz_greeting
    printf '\n\033[?25l'
    for ((t = 0; t <= 80; t++)); do
        p=$((t * 100 / 80))
        xt_render_bar "$W" "$p" "$t"
        printf '\r  %s %3d%%\033[K' "$XT_BAROUT" "$p"
        sleep 0.05
    done
    printf '\033[?25h\n\n\033[2mНажми любую клавишу…\033[0m'
    IFS= read -rsn1 _
}

# главное окно кастомизации
theme() {
    local sel=0 a b
    xt_load
    while true; do
        xt_refresh
        xt_render_bar 24 60 14
        xt_hdr "XSAZ THEME — КАСТОМИЗАЦИЯ" "Enter изменить | P предпросмотр" "Q/Esc выход" "Бар: $XT_BAROUT 60%"
        XT_ITEMS=(
            "Шрифт Termux…"
            "Цвет бара        $(xt_sw "$XT_BAR")"
            "Цвет блика       $(xt_sw "$XT_SHINE")"
            "Символы бара     $XT_FULL$XT_FULL$XT_FULL$XT_VOID$XT_VOID"
            "Анимация бара    $XT_ANIM"
            "Стиль линии      $XT_FRAME"
            "Приветствие      $XT_GREET"
            "Цвет имени       $(xt_sw "$XT_ACCENT")"
            "Цвет хоста       $(xt_sw "$XT_ACCENT2")"
            "Текст: $XT_USER@$XT_HOST"
            "Предпросмотр"
            "Сбросить всё"
        )
        XT_FOOT='файл: ~/.xsaz_theme'
        XT_IDX=$sel
        xt_cls
        xt_menu
        sel=$XT_IDX
        case $XT_KEY in
            q|esc|left) break ;;
            p) xt_preview ;;
            enter|right|e)
                case $sel in
                    0) xsaz_font_menu ;;
                    1) xt_pick_color "ЦВЕТ ПРОГРЕСС-БАРА" && XT_BAR=$XT_COLOR ;;
                    2) xt_pick_color "ЦВЕТ БЛИКА / ДОП. ЦВЕТ" && XT_SHINE=$XT_COLOR ;;
                    3)
                        XT_TMP="$XT_FULL $XT_VOID"
                        xt_choose "СИМВОЛЫ БАРА" XT_TMP \
                            "█ ░|██████░░░░  Блоки" \
                            "▓ ░|▓▓▓▓▓▓░░░░  Плотные блоки" \
                            "■ □|■■■■■■□□□□  Квадраты" \
                            "▰ ▱|▰▰▰▰▰▰▱▱▱▱  Плитки" \
                            "▮ ▯|▮▮▮▮▮▮▯▯▯▯  Столбики" \
                            "● ○|●●●●●●○○○○  Точки" \
                            "━ ─|━━━━━━──────  Линия" \
                            "= ·|======······  Равно" \
                            "# -|######----  ASCII" \
                            && { XT_FULL=${XT_TMP%% *}; XT_VOID=${XT_TMP##* }; }
                        ;;
                    4)
                        xt_choose "АНИМАЦИЯ БАРА" XT_ANIM \
                            "shine|shine — бегущий блик" \
                            "pulse|pulse — пульсация" \
                            "rainbow|rainbow — радуга" \
                            "stripes|stripes — бегущие полосы" \
                            "none|none — без анимации"
                        ;;
                    5)
                        xt_choose "СТИЛЬ ЛИНИИ" XT_FRAME \
                            "rounded|rounded  ╭─ ╰─" \
                            "sharp|sharp    ┌─ └─" \
                            "double|double   ╔═ ╚═" \
                            "heavy|heavy    ┏━ ┗━" \
                            "ascii|ascii    +- +-"
                        ;;
                    6)
                        xt_choose "СТИЛЬ ПРИВЕТСТВИЯ" XT_GREET \
                            "box|box — рамка слева" \
                            "bar|bar — рамка + бар заряда" \
                            "line|line — имя@хост и линия под ним" \
                            "minimal|minimal — одна строка" \
                            "off|off — без приветствия"
                        ;;
                    7) xt_pick_color "ЦВЕТ ИМЕНИ" && XT_ACCENT=$XT_COLOR ;;
                    8) xt_pick_color "ЦВЕТ ХОСТА" && XT_ACCENT2=$XT_COLOR ;;
                    9)
                        xt_cls
                        read -erp 'Имя (до @): ' -i "$XT_USER" a
                        read -erp 'Хост (после @): ' -i "$XT_HOST" b
                        [[ -n $a ]] && XT_USER=$a
                        [[ -n $b ]] && XT_HOST=$b
                        ;;
                    10) xt_preview ;;
                    11)
                        xt_cls
                        printf 'Сбросить тему к стандартной? [y/N] '
                        IFS= read -rsn1 a
                        [[ $a == [yY] ]] && { rm -f "$XT_CFG"; xt_defaults; }
                        ;;
                esac
                xt_save
                ;;
        esac
    done
    xt_cls
}

xt_load
xsaz_set_prompt

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
    xt_load

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

        xt_render_bar "$W" "$p" "$t"
        printf '\r  %s %3d%% %s\033[K' "$XT_BAROUT" "$p" "$label"
        t=$((t + 1))
        sleep 0.05
    done

    wait "$pid"; rc=$?
    trap - INT
    [[ $mon ]] && set -m
    printf '\r\033[K\033[?25h'
    rm -f "$st"

    if ((rc == 0)); then
        local sa=$XT_ANIM; XT_ANIM=none
        xt_render_bar "$W" 100 0; XT_ANIM=$sa
        printf '  %s 100%%\n' "$XT_BAROUT"
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
        search)        shift; search "$@" ;;
        upgrade|up)    apt update && apt full-upgrade ;;
        *)             command pkg "$@" ;;
    esac
}


# XSAZ SEARCH
# Категории: "Название::regex по имени и описанию пакета"
XT_CATS=(
"Графика и изображения::image|graphic|draw|paint|photo|picture|svg|png|jpeg|imagemagick|gimp|inkscape|vector|pixel|render|screenshot|wallpaper"
"Аудио и музыка::audio|music|sound|mp3|midi|synth|pulseaudio|sox|opus|flac|vorbis|speech|tts|podcast|alsa|pipewire"
"Видео и медиа::video|ffmpeg|mpv|stream|youtube|media|codec|x264|x265|vlc|gstreamer|subtitle|camera"
"Разработка и языки::compiler|interpreter|programming|debugger|cmake|clang|llvm|rust|golang|python|nodejs|openjdk|lua|ruby|php|assembler|gdb|build system"
"Сеть и интернет::network|http|ssh|dns|proxy|vpn|wget|curl|ftp|browser|webserver|wifi|nmap|tor|torrent|wireguard|netcat"
"Безопасность и пентест::security|crypt|password|pentest|scanner|hash|ssl|gpg|forensic|exploit|brute|sqlmap|hydra|metasploit"
"Игры и эмуляторы::game|emulator|arcade|chess|puzzle|roguelike|sdl|retro|solitaire|minecraft"
"Текст и редакторы::editor|vim|nano|emacs|markdown|pager|spell|text processing|regex|diff"
"Система и утилиты::monitor|process|disk|file manager|archive|compress|backup|usb|htop|system info|sync|cron|tmux|screen"
"Рабочий стол и GUI::desktop|x11|xfce|window manager|gtk|qt|wayland|vnc|display|openbox|lxde|panel"
"Базы данных::database|sql|redis|mongo|sqlite|postgres|mariadb|key-value"
"Наука и математика::math|calculator|science|plot|numerical|statistic|octave|astronomy|symbolic|gnuplot"
"Документы, PDF, книги::pdf|document|office|latex|ebook|epub|libreoffice|pandoc|djvu"
"Все пакеты::"
)

xt_inst_refresh() {
    local n
    XT_INST=()
    while IFS= read -r n; do XT_INST[$n]=1; done < <(dpkg-query -W -f='${Package}\n' 2>/dev/null)
}

xt_pkg_item() {
    local n=${XT_CUR[$1]%% *} pre='    '
    [[ -n ${XT_INST[$n]} ]] && pre='  ✔ '
    [[ -n ${XT_MARK[$n]} ]] && pre='[x] '
    XT_ITEMS[$1]="$pre${XT_CUR[$1]}"
}

# список пакетов: xt_pkg_list "Заголовок" re|word "значение"
xt_pkg_list() {
    local title=$1 mode=$2 arg=$3 i n flt rebuild=1
    local -a orig=() found=() want=()
    if ! command -v apt-cache >/dev/null 2>&1; then
        printf 'apt-cache не найден\n'; IFS= read -rsn1 _; return 1
    fi
    xt_cls
    printf 'Загружаю список пакетов…\n'
    if [[ $mode == re && -n $arg ]]; then
        mapfile -t orig < <(apt-cache search . 2>/dev/null | grep -iE -- "$arg" | sort -u)
    elif [[ $mode == re ]]; then
        mapfile -t orig < <(apt-cache search . 2>/dev/null | sort -u)
    else
        mapfile -t orig < <(apt-cache search "$arg" 2>/dev/null | sort -u)
    fi
    if ((${#orig[@]} == 0)); then
        printf '\nНичего не найдено. Попробуй сначала: apt update\n\nНажми любую клавишу…'
        IFS= read -rsn1 _
        return 1
    fi
    XT_CUR=("${orig[@]}")
    xt_inst_refresh
    XT_IDX=0
    xt_cls
    while true; do
        if ((rebuild)); then
            XT_ITEMS=()
            for ((i = 0; i < ${#XT_CUR[@]}; i++)); do xt_pkg_item "$i"; done
            rebuild=0
        fi
        xt_hdr "$title" "Enter инфо | E отметка | I установка" "/ фильтр | Q назад | ✔ уже стоит"
        XT_FOOT="отмечено: ${#XT_MARK[@]}"
        xt_menu
        case $XT_KEY in
            q|esc|left) return 0 ;;
            e)
                n=${XT_CUR[XT_IDX]%% *}
                if [[ -n ${XT_MARK[$n]} ]]; then unset 'XT_MARK[$n]'; else XT_MARK[$n]=1; fi
                xt_pkg_item "$XT_IDX"
                ((XT_IDX < ${#XT_CUR[@]} - 1)) && ((XT_IDX++))
                ;;
            enter|right)
                n=${XT_CUR[XT_IDX]%% *}
                xt_cls
                if command -v less >/dev/null 2>&1; then
                    command apt show "$n" 2>/dev/null | less -R
                else
                    command apt show "$n" 2>/dev/null | head -n 40
                    printf '\nНажми любую клавишу…'; IFS= read -rsn1 _
                fi
                xt_cls
                ;;
            i)
                want=("${!XT_MARK[@]}")
                ((${#want[@]} == 0)) && want=("${XT_CUR[XT_IDX]%% *}")
                xt_cls
                printf 'Установка: %s\n\n' "${want[*]}"
                if apt install "${want[@]}"; then XT_MARK=(); fi
                xt_inst_refresh
                rebuild=1
                printf '\nНажми любую клавишу…'; IFS= read -rsn1 _
                xt_cls
                ;;
            /)
                xt_cls
                read -erp 'Фильтр (пусто = сбросить): ' flt
                if [[ -z $flt ]]; then
                    XT_CUR=("${orig[@]}")
                else
                    mapfile -t found < <(printf '%s\n' "${orig[@]}" | grep -iE -- "$flt" 2>/dev/null)
                    if ((${#found[@]})); then
                        XT_CUR=("${found[@]}")
                    else
                        printf 'Ничего не найдено\n'; sleep 1
                    fi
                fi
                XT_IDX=0; rebuild=1
                xt_cls
                ;;
        esac
    done
}

# поиск репозиториев на GitHub
xt_gh_search() {
    local q line name
    local -a res=()
    xt_cls
    read -erp 'Поиск на GitHub: ' q
    [[ -z $q ]] && return 0
    if ! command -v curl >/dev/null 2>&1; then
        printf 'Нужен curl: apt install curl\n'; IFS= read -rsn1 _; return 1
    fi
    printf 'Ищу…\n'
    mapfile -t res < <(
        curl -fsSL -G --data-urlencode "q=$q" -d per_page=40 -d sort=stars \
            -H 'Accept: application/vnd.github+json' \
            https://api.github.com/search/repositories 2>/dev/null |
        awk '
        /^ *"full_name":/ { n=$0; sub(/^ *"full_name": "/,"",n); sub(/",?$/,"",n) }
        /^ *"description":/ {
            d=$0; sub(/^ *"description": /,"",d); sub(/,$/,"",d)
            if (d=="null") d=""; else { sub(/^"/,"",d); sub(/"$/,"",d); gsub(/\\"/,"\"",d) }
        }
        /^ *"stargazers_count":/ { s=$0; gsub(/[^0-9]/,"",s); print n " | ★" s " | " d; d="" }'
    )
    if ((${#res[@]} == 0)); then
        printf '\nНичего не найдено (или нет интернета / лимит GitHub).\n\nНажми любую клавишу…'
        IFS= read -rsn1 _
        return 1
    fi
    XT_ITEMS=("${res[@]}")
    XT_IDX=0
    xt_cls
    while true; do
        xt_hdr "GITHUB: $q" "↑↓ выбор | Enter/E клонировать" "Q/Esc назад"
        XT_FOOT=''
        xt_menu
        case $XT_KEY in
            q|esc|left) return 0 ;;
            enter|right|e)
                line=${XT_ITEMS[XT_IDX]}
                name=${line%% *}
                xsaz_clone "https://github.com/$name.git"
                xt_cls
                ;;
        esac
    done
}

search() {
    local q="$*" sel=0 i k
    local -a names=() regs=()
    xt_load
    XT_MARK=()
    if [[ -n $q ]]; then
        xt_pkg_list "ПОИСК: $q" word "$q"
        xt_cls
        return 0
    fi
    for k in "${XT_CATS[@]}"; do names+=("${k%%::*}"); regs+=("${k#*::}"); done
    xt_cls
    while true; do
        XT_ITEMS=("${names[@]}" "Поиск по слову…" "Поиск на GitHub…" "Клонировать репозиторий…" "Выход")
        xt_hdr "XSAZ SEARCH" "↑↓ выбор | Enter открыть" "Q/Esc выход"
        XT_FOOT=''
        XT_IDX=$sel
        xt_menu
        sel=$XT_IDX
        case $XT_KEY in
            q|esc|left) break ;;
            enter|right|e)
                if ((sel < ${#names[@]})); then
                    xt_pkg_list "${names[sel]^^}" re "${regs[sel]}"
                else
                    case $((sel - ${#names[@]})) in
                        0) xt_cls; read -erp 'Что искать: ' i
                           [[ -n $i ]] && xt_pkg_list "ПОИСК: $i" word "$i" ;;
                        1) xt_gh_search ;;
                        2) xsaz_clone ;;
                        3) break ;;
                    esac
                fi
                xt_cls
                ;;
        esac
    done
    xt_cls
}

# XSAZ CLONE
xsaz_clone() {
    local url=$1 name dest target ans rc prefix=${PREFIX:-/data/data/com.termux/files/usr}
    local -a depth=()
    xt_load
    if ! command -v git >/dev/null 2>&1; then
        printf 'git не установлен. Установить? [Y/n] '
        IFS= read -rsn1 ans; printf '\n'
        [[ $ans == [nN] ]] && return 1
        apt install git || return 1
    fi
    xt_cls
    if [[ -z $url ]]; then
        printf '%s%s%s XSAZ CLONE%s\n\n' "$C_A" "$F_TL" "$F_H" "$C_R"
        read -erp 'Ссылка (или user/repo): ' url
    fi
    url=${url//[[:space:]]/}
    [[ -z $url ]] && return 1
    if [[ $url =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then url="https://github.com/$url.git"; fi
    name=${url%/}; name=${name##*/}; name=${name%.git}; name=${name##*:}

    XT_ITEMS=("Сюда: $PWD" "В префикс: $prefix/opt" "В домашнюю папку: ~" "Своя папка (ввести путь)…")
    xt_hdr "CLONE: $name" "Куда клонировать?" "Enter выбрать | Q/Esc отмена"
    XT_FOOT=''
    XT_IDX=0
    xt_cls
    while true; do
        xt_menu
        case $XT_KEY in
            q|esc|left) return 1 ;;
            enter|right|e)
                case $XT_IDX in
                    0) dest=$PWD ;;
                    1) dest=$prefix/opt ;;
                    2) dest=$HOME ;;
                    3) xt_cls
                       read -erp 'Путь: ' -i "$PWD/" dest
                       dest=${dest/#\~/$HOME} ;;
                esac
                [[ -n $dest ]] && break
                ;;
        esac
    done

    XT_ITEMS=("Полный клон" "Быстрый (--depth 1, меньше трафика)")
    xt_hdr "CLONE: $name" "Тип клона" "Enter выбрать | Q/Esc отмена"
    XT_IDX=0
    xt_cls
    while true; do
        xt_menu
        case $XT_KEY in
            q|esc|left) return 1 ;;
            enter|right|e) ((XT_IDX == 1)) && depth=(--depth 1); break ;;
        esac
    done

    xt_cls
    target=$dest/$name
    if [[ -e $target ]]; then
        printf '\033[1;31m✖ Уже существует: %s\033[0m\n\nНажми любую клавишу…' "$target"
        IFS= read -rsn1 _
        return 1
    fi
    mkdir -p -- "$dest" || return 1
    printf '%s▶ git clone%s %s\n  → %s\n\n' "$C_A" "$C_R" "$url" "$target"
    git clone --progress "${depth[@]}" -- "$url" "$target"
    rc=$?
    printf '\n'
    if ((rc == 0)); then
        printf '\033[1;32m✔ Готово:\033[0m %s\n\nПерейти в папку? [Y/n] ' "$target"
        IFS= read -rsn1 ans; printf '\n'
        [[ $ans == [nN] ]] || builtin cd -- "$target"
    else
        printf '\033[1;31m✖ Ошибка клонирования (код %s)\033[0m\n  Проверь ссылку и интернет.\n\nНажми любую клавишу…' "$rc"
        IFS= read -rsn1 _
    fi
    return $rc
}

clone() { xsaz_clone "$@"; }

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
    local j bat state free col bc now title tlen l sa
    local -a info=()

    [[ $XT_GREET == off ]] && return 0

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
    bc=$'\033['"$col"'m'

    free=$(df -h "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')
    now=$(date '+%d.%m.%Y %H:%M')

    if [[ -n $bat ]]; then
        if [[ $XT_GREET == bar ]]; then
            sa=$XT_ANIM; XT_ANIM=none
            xt_render_bar 14 "$bat" 0
            XT_ANIM=$sa
            info+=("Заряд:    $XT_BAROUT $bc$bat%$C_R$state")
        else
            info+=("Заряд:    $bc$bat%$C_R$state")
        fi
    fi
    info+=("Свободно: ${free:-?}")
    info+=("Время:    $now")

    title="$C_A$XT_USER$C_R@$C_B$XT_HOST$C_R"
    tlen=$((${#XT_USER} + ${#XT_HOST} + 1))

    case $XT_GREET in
        minimal)
            printf '%s' "$title"
            [[ -n $bat ]] && printf '  %s%s%%%s' "$bc" "$bat" "$C_R"
            printf '  %s  %s\n' "${free:-?}" "$(date '+%H:%M')"
            ;;
        line)
            printf '%s\n%s%s%s\n' "$title" "$C_A" "$(xt_rule "$tlen")" "$C_R"
            for l in "${info[@]}"; do printf '%s\n' "$l"; done
            ;;
        *)
            printf '%s%s%s%s %s\n' "$C_A" "$F_TL" "$F_H" "$C_R" "$title"
            for l in "${info[@]}"; do printf '%s%s%s %s\n' "$C_A" "$F_V" "$C_R" "$l"; done
            printf '%s%s%s%s\n' "$C_A" "$F_BL" "$(xt_rule 26)" "$C_R"
            ;;
    esac
}

if [[ $- == *i* ]]; then
    xsaz_greeting
fi
EOF

source ~/.bashrc
