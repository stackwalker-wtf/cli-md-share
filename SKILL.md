---
name: cli-md-share
description: >
  把 Markdown 上传到 rentry.co，立刻拿到一个免登录可打开的渲染页 URL。
  当用户要把文档/笔记/说明发成在线链接、分享渲染好的 Markdown、
  或说「上传到在线」「发给我链接」时使用。无需账号、无需 API key。
  上传前必须先扫敏感信息，确认没有密钥/密码/私钥才能传。
---

# Markdown 在线分享

把 Markdown 发到 [rentry.co](https://rentry.co)，返回一个公开 URL。浏览器打开就是渲染好的页面，不是源码。

免登录、免 API key。内容永久保存，除非违规或作者自己删。单篇上限 20 万字符。匿名创建大约每 IP 每分钟 10 次。页面公开，任何人有链接就能看。

## 依赖

- `bash`、`curl`、`jq`、`grep`

## 上传前检查（硬门禁）

上传前必须确认没有敏感信息。不能跳过。用户说「直接传 / 不用检查」也不跳过。

先跑：

```bash
bash {baseDir}/scripts/scan.sh <file.md>
```

脚本只拦高置信密钥形态（私钥、GitHub/Slack/Stripe token、AKIA、JWT、带密码的连接串等）。退出码非 0 就禁止调用 `upload.sh`。

脚本扫不到的，自己把全文再看一遍。有下面这些也不能传：

- 密码、cookie、session、验证码、内网 token
- `.env` 里的值、云账号密钥、私钥、证书
- 身份证、手机号、银行卡、精确住址
- 未公开的客户数据、内部后台地址且带鉴权参数

有命中：停止。只说命中了哪一类、哪一行，不要把密钥值再复述一遍。让用户改成占位符后重新扫描。

不确定能不能公开：先问用户，等到明确「可以公开」再传。

扫描通过、全文也没有上述内容：才能调用 `upload.sh`。

## 用法

```bash
bash {baseDir}/scripts/scan.sh <file.md>
bash {baseDir}/scripts/upload.sh <file.md>
echo '# hi' | bash {baseDir}/scripts/upload.sh
bash {baseDir}/scripts/upload.sh note.md --title "标题" --url my-slug
```

stdout 只有渲染页 URL，直接发给用户。`edit_code` 在 stderr，需要改这篇时才提。

常用选项：

- `--url <slug>`：自定义短链（字母数字 `_` `-`，2-100 字符）
- `--edit-code <code>`：自定义编辑码；省略则随机，只显示一次
- `--title <标题>`：页面标题
- `--json`：输出原始 JSON

## 工作流

1. 用户要「发个在线链接 / 上传文档给我 URL」时用这个 skill，不要改用需要登录的 gist / GitHub Pages。
2. 内容已经是文件就用该路径；是对话里的 Markdown 就先写临时文件。
3. 先 `scan.sh`，再自己读一遍。未通过或未确认干净，不准上传。
4. 通过后才 `upload.sh`。把 stdout 的 URL 原样发给用户。
5. 默认不要强调 `edit_code`。只有用户明确说以后要改，才告诉他。
6. `429` 时脚本会重试。仍失败就原样报错，不要换别的 paste 站，除非用户要求。

## 注意

- rentry 的 `/raw` 默认不开放，用户要的是渲染页，给 `https://rentry.co/<slug>` 即可。
- 镜像站 `https://rentry.org` 也能开同一篇，但上传统一走 `rentry.co`。
- API 文档：https://github.com/radude/rentry
