#!/usr/bin/env bash
# 方式二：首次启动 RAGFlow（无 API Key 时）
# 在已安装 Docker 的终端中执行：./start_ragflow.sh 或 bash start_ragflow.sh

set -e
cd "$(dirname "$0")"

# 查找 docker 命令（支持 macOS Docker Desktop 未加入 PATH 的情况）
find_docker() {
  if command -v docker &>/dev/null; then
    echo "docker"
    return
  fi
  for path in /usr/local/bin/docker /Applications/Docker.app/Contents/Resources/bin/docker; do
    if [[ -x "$path" ]]; then
      echo "$path"
      return
    fi
  done
  return 1
}

DOCKER=$(find_docker) || true
if [[ -z "$DOCKER" ]]; then
  echo "错误: 未找到 docker 命令。"
  echo ""
  echo "请先安装 Docker Desktop："
  echo "  https://docs.docker.com/desktop/install/mac-install/"
  echo ""
  echo "若已安装，请从「应用程序」打开 Docker Desktop，等待其完全启动后，"
  echo "在「终端.app」中执行（Docker 会配置 PATH）："
  echo "  cd $(pwd)"
  echo "  ./start_ragflow.sh"
  echo ""
  echo "或在 Cursor 设置中为集成终端配置 PATH，使包含 docker 的目录生效。"
  exit 1
fi

COMPOSE="$DOCKER compose"
if ! $COMPOSE version &>/dev/null; then
  COMPOSE="${DOCKER}-compose"
  if ! command -v "$COMPOSE" &>/dev/null; then
    COMPOSE="$DOCKER compose"
  fi
fi

echo "使用: $DOCKER"
echo ""

echo "1. 设置 vm.max_map_count（macOS/Linux）..."
if $DOCKER run --rm --privileged --pid=host alpine sysctl -w vm.max_map_count=262144 2>/dev/null; then
  echo "   vm.max_map_count 已设置"
else
  echo "   跳过或失败（若为 Linux 请手动: sudo sysctl -w vm.max_map_count=262144）"
fi

echo ""
echo "2. 启动 RAGFlow（含依赖与 MCP）..."
$COMPOSE -f docker-compose.yml up -d

echo ""
echo "3. 等待服务就绪（约 30 秒）..."
sleep 30

echo ""
echo "4. 查看 RAGFlow 容器日志（Ctrl+C 退出）..."
$DOCKER logs -f docker-ragflow-cpu-1 2>/dev/null || $COMPOSE -f docker-compose.yml logs -f ragflow-cpu
