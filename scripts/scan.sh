#!/usr/bin/env bash
# 扫描即将上传的 Markdown，拦截常见密钥/凭据形态。
# 命中则退出 1。只打印规则名和行号，不回显密钥值。
# 依赖: bash, grep
set -euo pipefail

FILE=""

usage() {
  cat <<'EOF'
用法: scan.sh [文件]

  文件省略时从 stdin 读。
  通过：退出 0，stderr 打印「扫描通过」。
  命中：退出 1，stderr 打印规则名和行号，不打印密钥本身。
EOF
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage ;;
    -*)
      echo "未知选项: $1" >&2
      usage
      ;;
    *)
      if [ -n "$FILE" ]; then
        echo "错误: 只能指定一个文件" >&2
        exit 2
      fi
      FILE="$1"
      shift
      ;;
  esac
done

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

if [ -n "$FILE" ]; then
  if [ ! -f "$FILE" ]; then
    echo "错误: 文件不存在: $FILE" >&2
    exit 2
  fi
  cat "$FILE" > "$TMP"
else
  if [ -t 0 ]; then
    echo "错误: 没有文件，也没有 stdin" >&2
    usage
  fi
  cat > "$TMP"
fi

if [ ! -s "$TMP" ]; then
  echo "错误: 内容为空" >&2
  exit 2
fi

# name|extended-regex
# 只收高置信形态；PII / 上下文泄露由 SKILL.md 让模型人工看。
RULES=(
  'private-key|-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'openssh-private-key|-----BEGIN OPENSSH PRIVATE KEY-----'
  'aws-access-key|AKIA[0-9A-Z]{16}'
  'github-token|gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}'
  'slack-token|xox[baprs]-[A-Za-z0-9-]{10,}'
  'stripe-live-key|sk_live_[A-Za-z0-9]{16,}|rk_live_[A-Za-z0-9]{16,}'
  'google-api-key|AIza[0-9A-Za-z_-]{35}'
  'openai-key|sk-proj-[A-Za-z0-9_-]{20,}|sk-ant-[A-Za-z0-9_-]{20,}'
  'npm-token|npm_[A-Za-z0-9]{36}'
  'jwt|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
  'bearer-token|[Aa]uthorization:[[:space:]]*[Bb]earer[[:space:]]+[^[:space:]]{12,}'
  'discord-webhook|discord(app)?\.com/api/webhooks/[0-9]+/'
  'connection-uri|(postgres|postgresql|mysql|mongodb(\+srv)?|redis|amqp)://[^[:space:]/:]+:[^[:space:]/@]+@'
  'aws-secret-assignment|[Aa][Ww][Ss]_[Ss][Ee][Cc][Rr][Ee][Tt]_[Aa][Cc][Cc][Ee][Ss][Ss]_[Kk][Ee][Yy][[:space:]]*[=:][[:space:]]*[^[:space:]]+'
  'api-key-assignment|(api[_-]?key|secret[_-]?key|access[_-]?token)[[:space:]]*[=:][[:space:]]*['\''\"]?[A-Za-z0-9_\-]{12,}'
  'password-assignment|(password|passwd|pwd)[[:space:]]*[=:][[:space:]]*['\''\"]?[^[:space:]'\''\"]{8,}'
)

HITS=0
while IFS='|' read -r name pattern; do
  [ -z "$name" ] && continue
  LINES=$(grep -nE -- "$pattern" "$TMP" | cut -d: -f1 | paste -sd, - || true)
  if [ -n "$LINES" ]; then
    echo "  L${LINES}  ${name}" >&2
    HITS=1
  fi
done < <(printf '%s\n' "${RULES[@]}")

if [ "$HITS" -eq 1 ]; then
  echo "扫描未通过：疑似敏感信息。不要上传，先删掉或改成占位符再扫。" >&2
  exit 1
fi

echo "扫描通过" >&2
exit 0
