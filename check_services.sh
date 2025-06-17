#!/bin/bash

### ===[ Настраиваемые параметры ]===
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

WARN_USAGE=80
CRIT_USAGE=95

ADVICE_FILE="${HOME}/.status_script_advices"
SCRIPT_PATH=$(realpath "$0")
SYMLINK_PATH="/usr/bin/status"

### ===[ Проверка интерактивности ]===
[[ $- != *i* ]] && return 0 2>/dev/null || :

### ===[ Система советов ]===
function show_next_advice() {
    [ ! -f "$ADVICE_FILE" ] && touch "$ADVICE_FILE"

    # Совет 1
    if ! grep -q "SYMLINK_CREATED" "$ADVICE_FILE"; then
        if [ ! -L "$SYMLINK_PATH" ] || [ "$(realpath "$SYMLINK_PATH")" != "$SCRIPT_PATH" ]; then
            echo -e "${YELLOW}=== Совет 1/3 ===${RESET}"
            echo -e "Для быстрого доступа создайте симлинк:"
            echo -e "  ${CYAN}sudo ln -sf \"$SCRIPT_PATH\" \"$SYMLINK_PATH\"${RESET}"
            echo -e "После этого скрипт можно вызывать просто командой: ${CYAN}status${RESET}"
            echo "SYMLINK_CREATED" >> "$ADVICE_FILE"
            return 0
        else
            echo "SYMLINK_CREATED" >> "$ADVICE_FILE"
        fi
    fi

    # Совет 2
    if ! grep -q "BASHRC_ADDED" "$ADVICE_FILE"; then
        if ! grep -q "$SCRIPT_PATH" "${HOME}/.bashrc"; then
            echo -e "${YELLOW}=== Совет 2/3 ===${RESET}"
            echo -e "Для автозапуска при открытии терминала добавьте в ~/.bashrc:"
            echo -e "  ${CYAN}echo \"[[ -f $SCRIPT_PATH ]] && $SCRIPT_PATH\" >> ~/.bashrc${RESET}"
            echo "BASHRC_ADDED" >> "$ADVICE_FILE"
            return 0
        else
            echo "BASHRC_ADDED" >> "$ADVICE_FILE"
        fi
    fi

    # Совет 3
    if ! grep -q "INTERACTIVE_CHECK_ADDED" "$ADVICE_FILE"; then
        if ! grep -q "case \\$-" "$SCRIPT_PATH"; then
            echo -e "${YELLOW}=== Совет 3/3 ===${RESET}"
            echo -e "Добавьте проверку на интерактивность в начало скрипта:"
            echo -e "  ${CYAN}[[ \$- != *i* ]] && return 0 2>/dev/null || :${RESET}"
            echo "INTERACTIVE_CHECK_ADDED" >> "$ADVICE_FILE"
            return 0
        else
            echo "INTERACTIVE_CHECK_ADDED" >> "$ADVICE_FILE"
        fi
    fi

    return 1
}

### ===[ Показываем совет (если интерактивный запуск) ]===
show_next_advice

### ===[ Чёрный список и белый список ]===
ignore_exact="
chronyd
crond
dbus-broker
dracut-shutdown
gssproxy
irqbalance
kdump
kmod-static-nodes
NetworkManager-wait-online
nis-domainname
rpcbind
rpc-statd
rpc-statd-notify
rsyslog
sshd
vgauthd
vmtoolsd
auditd
lvm2-monitor
NetworkManager
polkit
"

ignore_prefix="
systemd-
"

whitelist="
nginx
php-fpm
redis
mariadb
coturn
vsftpd
pdns
dovecot
postfix
opendkim
fail2ban
vaultwarden
transmission-daemon
"

### ===[ Заголовок ]===
echo "
 _______________
< Vectoooooor >
 ---------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/
                ||----w |
                ||     ||
"
echo -e "${RED}"
grep PRETTY_NAME /etc/*release 2>/dev/null | head -n1 | cut -d= -f2 | tr -d '"'
echo -e "${RESET}"

### ===[ Сбор юнитов ]===
unit_files=$(systemctl list-unit-files --type=service --no-legend | awk '{print $1}' | sed 's/\.service$//')
active_units=$(systemctl list-units --type=service --state=active --no-legend | awk '{print $1}' | sed 's/\.service$//')

function in_exact_list() {
    local name=$1
    echo "$ignore_exact" | grep -qx "$name"
}

function in_prefix_list() {
    local name=$1
    for prefix in $ignore_prefix; do
        [[ "$name" == "$prefix"* ]] && return 0
    done
    return 1
}

function get_service_description() {
    local name=$1
    systemctl show "$name.service" --property=Description --no-pager 2>/dev/null | cut -d= -f2
}

function check_service() {
    local name="$1"

    in_exact_list "$name" && return
    in_prefix_list "$name" && return

    if ! echo "$unit_files" | grep -qx "$name"; then
        return
    fi

    local description=$(get_service_description "$name")
    if echo "$active_units" | grep -qx "$name"; then
        printf "%-20s %-30s %s\n" "${GREEN}running${RESET}" "$name" "$description"
    else
        printf "%-20s %-30s %s\n" "${RED}not running${RESET}" "$name" "$description"
    fi
}

combined=$(echo -e "${active_units}\n${whitelist}" | sort -u)

echo -e "${CYAN}--- Service Status ---${RESET}"
printf "%-20s %-30s %s\n" "STATUS" "SERVICE" "DESCRIPTION"
echo "------------------------------------------------------------------"
for svc in $combined; do
    check_service "$svc"
done

### ===[ Кто залогинен ]===
echo -e "${CYAN}--- Who is logged in ---${RESET}"
w

### ===[ Последние подключения ]===
echo -e "${CYAN}--- Last Logins ---${RESET}"
last -aF | head -n4 | tail -n3

### ===[ Использование дисков ]===
echo -e "${CYAN}--- Disk Usage (only above ${WARN_USAGE}%) ---${RESET}"
df -h -x tmpfs -x devtmpfs | while read -r line; do
    if echo "$line" | grep -qE '^Filesystem'; then
        echo "$line"
        continue
    fi

    usep=$(echo "$line" | awk '{ print $(NF-1) }' | tr -d '%')
    [[ ! "$usep" =~ ^[0-9]+$ ]] && continue

    if [ "$usep" -ge "$CRIT_USAGE" ]; then
        echo -e "${RED}${line}${RESET}"
    elif [ "$usep" -ge "$WARN_USAGE" ]; then
        echo -e "${YELLOW}${line}${RESET}"
    fi
done

### ===[ Память и аптайм ]===
echo -e "${CYAN}--- Memory ---${RESET}"
free -h

echo -e "${CYAN}--- Uptime ---${RESET}"
uptime
