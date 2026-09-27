#!/usr/bin/env bash
# ===================================================================
# QuantDinger 本机启动 (免 Docker: 原生 Postgres + Python 后端)
#   bash start_local.sh          # 起 Postgres(15432) + 后端(15000)
#   bash start_local.sh stop     # 全停
#   PG_CTL / PSQL 可用环境变量覆盖 (默认 Intel Homebrew postgresql@16 路径)
#   前提: pgdata/ 已 initdb, backend_api_python/.venv 与 .env 已就绪
# ===================================================================
set -euo pipefail
QD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PG_CTL="${PG_CTL:-/usr/local/bin/pg_ctl}"
PSQL="${PSQL:-/usr/local/bin/psql}"
PIDFILE="$QD_ROOT/backend_api_python/qd_server.pid"

if [[ "${1:-}" == "stop" ]]; then
  if [[ -f "$PIDFILE" ]]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
  LC_ALL=C "$PG_CTL" -D "$QD_ROOT/pgdata" stop 2>/dev/null || true
  echo "==> QuantDinger stopped"
  exit 0
fi

# Postgres (独立集群, 端口 15432; LC_ALL=C 避免 macOS 中文 locale 下多线程崩溃)
if ! "$PSQL" -h 127.0.0.1 -p 15432 -U postgres -c "select 1" >/dev/null 2>&1; then
  LC_ALL=C LANG=C "$PG_CTL" -D "$QD_ROOT/pgdata" -o "-p 15432 -k /tmp" -l "$QD_ROOT/pgdata/pg.log" start
  sleep 2
fi
echo "==> Postgres :15432 up"

# 后端 (端口在 backend_api_python/.env 的 PYTHON_API_PORT=15000; 5000 被 macOS AirPlay 占用)
if ! curl -s -m3 -o /dev/null http://127.0.0.1:15000/; then
  cd "$QD_ROOT/backend_api_python"
  nohup .venv/bin/python run.py > qd_server.log 2>&1 &
  echo $! > "$PIDFILE"
  sleep 8
fi
curl -s -m5 -o /dev/null -w "==> backend :15000 HTTP %{http_code}\n" http://127.0.0.1:15000/
echo "==> QuantDinger 后端: http://127.0.0.1:15000/"
