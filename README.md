# cli-md-share

Pi / Agent Skills：把 Markdown 上传到 [rentry.co](https://rentry.co)，立刻拿到免登录可打开的渲染页 URL。

无需账号、无需 API key。浏览器打开返回的链接就是渲染好的 Markdown。

## 安装

把本仓库放到 agent 的 skills 目录，例如：

```bash
git clone https://github.com/stackwalker-wtf/cli-md-share.git ~/.agents/skills/custom/cli-md-share
```

需要 `bash`、`curl`、`jq`。

## 用法

```bash
bash scripts/upload.sh note.md
echo '# hello' | bash scripts/upload.sh
bash scripts/upload.sh note.md --title "标题" --url my-slug
```

stdout 只有渲染页 URL。`edit_code` 打到 stderr。

选项：

- `--url <slug>`：自定义短链
- `--edit-code <code>`：自定义编辑码
- `--title <标题>`：页面标题
- `--json`：输出原始 JSON

## 触发

用户说「写个文档上传到在线，发给我链接」这类需求时使用。详见 `SKILL.md`。

## 许可

MIT
