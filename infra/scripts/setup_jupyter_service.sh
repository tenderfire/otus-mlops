#!/bin/bash

# Скрипт для настройки systemd сервиса для Jupyter Notebook
# Запускает Jupyter на 0.0.0.0:8888 при старте системы

set -e

echo "=== Настройка systemd сервиса для Jupyter Notebook ==="

# Определяем пользователя (обычно ubuntu на Dataproc)
JUPYTER_USER="${JUPYTER_USER:-ubuntu}"
JUPYTER_HOME="/home/${JUPYTER_USER}"

# Проверяем установку Jupyter
echo "Проверяем установку Jupyter..."
if command -v jupyter &> /dev/null; then
    JUPYTER_CMD=$(which jupyter)
    echo "✓ Jupyter найден: $JUPYTER_CMD"
elif [ -f "/opt/conda/bin/jupyter" ]; then
    JUPYTER_CMD="/opt/conda/bin/jupyter"
    echo "✓ Jupyter найден в conda: $JUPYTER_CMD"
elif [ -f "/usr/local/bin/jupyter" ]; then
    JUPYTER_CMD="/usr/local/bin/jupyter"
    echo "✓ Jupyter найден: $JUPYTER_CMD"
else
    echo "⚠ Jupyter не найден в стандартных местах. Пытаемся найти через PATH..."
    JUPYTER_CMD="jupyter"
    # Проверяем через python
    if python3 -m jupyter --version &> /dev/null; then
        JUPYTER_CMD="python3 -m jupyter"
        echo "✓ Jupyter доступен через python3 -m jupyter"
    else
        echo "❌ Jupyter не установлен. Установите его перед продолжением."
        exit 1
    fi
fi

# Проверяем версию
echo "Версия Jupyter:"
eval "$JUPYTER_CMD --version" || python3 -m jupyter --version

# Создаем директорию для логов
JUPYTER_LOG_DIR="/var/log/jupyter"
sudo mkdir -p "$JUPYTER_LOG_DIR"
sudo chown "$JUPYTER_USER:$JUPYTER_USER" "$JUPYTER_LOG_DIR"

# Создаем директорию для конфигурации Jupyter, если её нет
JUPYTER_CONFIG_DIR="$JUPYTER_HOME/.jupyter"
mkdir -p "$JUPYTER_CONFIG_DIR"

# Генерируем конфигурационный файл Jupyter, если его нет
if [ ! -f "$JUPYTER_CONFIG_DIR/jupyter_notebook_config.py" ]; then
    echo "Генерируем конфигурационный файл Jupyter..."
    eval "$JUPYTER_CMD notebook --generate-config" || python3 -m jupyter notebook --generate-config
fi

# Настраиваем Jupyter для работы на 0.0.0.0
echo "Настраиваем Jupyter для работы на 0.0.0.0:8888..."
JUPYTER_CONFIG="$JUPYTER_CONFIG_DIR/jupyter_notebook_config.py"

# Добавляем настройки в конфигурационный файл
if ! grep -q "c.NotebookApp.ip = '0.0.0.0'" "$JUPYTER_CONFIG" 2>/dev/null; then
    echo "" >> "$JUPYTER_CONFIG"
    echo "# Настройки для запуска на всех интерфейсах" >> "$JUPYTER_CONFIG"
    echo "c.NotebookApp.ip = '0.0.0.0'" >> "$JUPYTER_CONFIG"
    echo "c.NotebookApp.port = 8888" >> "$JUPYTER_CONFIG"
    echo "c.NotebookApp.open_browser = False" >> "$JUPYTER_CONFIG"
    echo "c.NotebookApp.allow_root = False" >> "$JUPYTER_CONFIG"
    echo "# Отключаем токен для упрощения доступа (при необходимости можно включить)" >> "$JUPYTER_CONFIG"
    echo "# c.NotebookApp.token = ''" >> "$JUPYTER_CONFIG"
    echo "# c.NotebookApp.password = ''" >> "$JUPYTER_CONFIG"
    echo "✓ Конфигурация обновлена"
else
    echo "✓ Конфигурация уже содержит необходимые настройки"
fi

# Создаем systemd service файл
echo "Создаем systemd service файл..."
SERVICE_FILE="/etc/systemd/system/jupyter-notebook.service"

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Jupyter Notebook Service
After=network.target

[Service]
Type=simple
User=$JUPYTER_USER
Group=$JUPYTER_USER
WorkingDirectory=$JUPYTER_HOME
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/conda/bin"
Environment="HOME=$JUPYTER_HOME"
ExecStart=$JUPYTER_CMD notebook --config=$JUPYTER_CONFIG_DIR/jupyter_notebook_config.py
Restart=always
RestartSec=10
StandardOutput=append:$JUPYTER_LOG_DIR/jupyter.log
StandardError=append:$JUPYTER_LOG_DIR/jupyter-error.log

[Install]
WantedBy=multi-user.target
EOF

# Устанавливаем права на файл сервиса
sudo chmod 644 "$SERVICE_FILE"

# Перезагружаем systemd
echo "Перезагружаем systemd daemon..."
sudo systemctl daemon-reload

# Включаем автозапуск при старте системы
echo "Включаем автозапуск сервиса..."
sudo systemctl enable jupyter-notebook.service

# Запускаем сервис
echo "Запускаем сервис..."
sudo systemctl start jupyter-notebook.service

# Проверяем статус
echo ""
echo "=== Статус сервиса ==="
sudo systemctl status jupyter-notebook.service --no-pager -l || true

echo ""
echo "=== Проверка порта 8888 ==="
sleep 2
if sudo netstat -tuln | grep -q ":8888 " || sudo ss -tuln | grep -q ":8888 "; then
    echo "✓ Jupyter Notebook слушает на порту 8888"
else
    echo "⚠ Порт 8888 пока не активен. Проверьте логи:"
    echo "  sudo journalctl -u jupyter-notebook.service -f"
fi

echo ""
echo "=== Полезные команды ==="
echo "Просмотр логов:     sudo journalctl -u jupyter-notebook.service -f"
echo "Статус сервиса:     sudo systemctl status jupyter-notebook.service"
echo "Перезапуск:         sudo systemctl restart jupyter-notebook.service"
echo "Остановка:          sudo systemctl stop jupyter-notebook.service"
echo "Отключение:         sudo systemctl disable jupyter-notebook.service"

echo ""
echo "✓ Настройка завершена!"


