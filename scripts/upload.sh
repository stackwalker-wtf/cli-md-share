#!/usr/bin/env bash
# 把 Markdown 上传到 rentry.co，返回可打开的渲染页 URL。
# 免登录、免 API key。依赖: bash, curl, jq
set -euo pipefail

API="https://rentry.co/api/new"
FILE=""
CUSTOM_URL=""
EDIT_CODE=""
TITLE=""
JSON_OUT=0

usage() {
  cat <<'EOF'
用法: upload.sh [文件] [--url <slug>] [--edit-code <code>] [--title <标题>] [--json]

  文件省略时从 stdin 读 Markdown。
  --url        自定义短链，只能含字母数字下划线连字符，2-100 字符；省略则随机
  --edit-code  自定义编辑码，以后可改这篇；省略则随机（只显示一次）
  --title      页面标题（写入 rentry PAGE_TITLE 元数据）
  --json       输出原始 JSON，而不是人类可读格式

成功时 stdout 只打印渲染页 URL。打开该 URL 即可看到渲染好的 Markdown。
edit_code / url_short 打到 stderr，避免污染可复制的链接。
EOF
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage ;;
    --url)
      CUSTOM_URL="${2:-}"
      shift 2
      ;;
    --edit-code)
      EDIT_CODE="${2:-}"
      shift 2
      ;;
    --title)
      TITLE="${2:-}"
      shift 2
      ;;
    --json)
      JSON_OUT=1
      shift
      ;;
    --)
      shift
      break
      ;;
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

# rentry 上限 200000 字符。用字节数近似拦截明显超限。
BYTES=$(wc -c < "$TMP" | tr -d ' ')
if [ "$BYTES" -gt 200000 ]; then
  echo "错误: 超过 rentry 20 万字符上限（当前 ${BYTES} 字节）" >&2
  exit 2
fi

DATA=(--data-urlencode "text@$TMP")
[ -n "$CUSTOM_URL" ] && DATA+=(--data-urlencode "url=$CUSTOM_URL")
[ -n "$EDIT_CODE" ] && DATA+=(--data-urlencode "edit_code=$EDIT_CODE")
if [ -n "$TITLE" ]; then
  DATA+=(--data-urlencode "metadata=PAGE_TITLE = $TITLE")
fi

post() {
  curl -sS --retry 2 --retry-all-errors \
    -H "Accept: application/json" \
    "${DATA[@]}" \
    "$API"
}

BODY=""
for attempt in 1 2 3; do
  BODY=$(post) || {
    echo "错误: 请求失败" >&2
    exit 1
  }
  STATUS=$(printf '%s' "$BODY" | jq -r '.status // empty' 2>/dev/null || true)
  if [ "$STATUS" = "429" ]; then
    sleep $((attempt * 2))
    continue
  fi
  break
done

if ! printf '%s' "$BODY" | jq -e . >/dev/null 2>&1; then
  echo "错误: 非 JSON 响应:" >&2
  printf '%s\n' "$BODY" >&2
  exit 1
fi

if [ "$JSON_OUT" -eq 1 ]; then
  printf '%s\n' "$BODY" | jq .
  STATUS=$(printf '%s' "$BODY" | jq -r '.status')
  [ "$STATUS" = "200" ] || exit 1
  exit 0
fi

STATUS=$(printf '%s' "$BODY" | jq -r '.status')
if [ "$STATUS" != "200" ]; then
  CONTENT=$(printf '%s' "$BODY" | jq -r '.content // empty')
  ERRORS=$(printf '%s' "$BODY" | jq -r '
    if (.errors | type) == "object" then
      .errors | to_entries | map("\(.key): \(.value)") | join("\n")
    else
      .errors // empty
    end
  ')
  echo "错误: rentry 返回 status=$STATUS" >&2
  [ -n "$CONTENT" ] && echo "$CONTENT" >&2
  [ -n "$ERRORS" ] && echo "$ERRORS" >&2
  exit 1
fi

URL=$(printf '%s' "$BODY" | jq -r '.url')
SHORT=$(printf '%s' "$BODY" | jq -r '.url_short')
CODE=$(printf '%s' "$BODY" | jq -r '.edit_code')

echo "$URL"
echo "edit_code: $CODE" >&2
echo "url_short: $SHORT" >&2
