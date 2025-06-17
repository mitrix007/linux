#!/bin/bash
# Скрипт создания базы данных, пользователя и генерации пароля
# Подходит для Atlassian Jira, Confluence и других приложений
# Поддерживает выбор кодировки и collation

read -p 'NAME (будет использоваться как префикс): ' NAME
read -p 'CHARSET (по умолчанию: utf8mb4): ' CHARSET
read -p 'COLLATION (по умолчанию: utf8mb4_bin): ' COLLATE

# Значения по умолчанию
CHARSET=${CHARSET:-utf8mb4}
COLLATE=${COLLATE:-utf8mb4_bin}

MAINUSER="${NAME}_user_prod"
MAINPWD="$(openssl rand -base64 12)"
MAINDB="${NAME}_db_prod"

mysql -uroot <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS \`${MAINDB}\` CHARACTER SET ${CHARSET} COLLATE ${COLLATE};
CREATE USER IF NOT EXISTS '${MAINUSER}'@'%' IDENTIFIED BY '${MAINPWD}';
GRANT ALL PRIVILEGES ON \`${MAINDB}\`.* TO '${MAINUSER}'@'%';
GRANT GRANT OPTION ON \`${MAINDB}\`.* TO '${MAINUSER}'@'%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Вывод
echo ""
echo "✅ MySQL база и пользователь успешно созданы:"
echo "  ┌──────────────────────────────"
echo "  │ База данных:     $MAINDB"
echo "  │ Пользователь:    $MAINUSER"
echo "  │ Пароль:          $MAINPWD"
echo "  │ Кодировка:       $CHARSET"
echo "  │ Collation:       $COLLATE"
echo "  │ Хост:            $(hostname -f)"
echo "  └──────────────────────────────"
echo ""
echo "🗑 Чтобы удалить базу и пользователя, выполните команды:"
echo ""
echo "mysql -uroot -p -e \"DROP DATABASE IF EXISTS \\\`$MAINDB\\\`; DROP USER IF EXISTS '$MAINUSER'@'%'; FLUSH PRIVILEGES;\""
echo ""
