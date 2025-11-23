# CLAUDE.md — curlpj 插件的使用说明（Claude 风格文档）

## 🧩 概述

`curlpj` 是一个面向日常开发者的增强版 cURL 工具，用于在终端中更便捷地调试 API。
它的设计目标是：

- 保持与 `curl` **100% 参数兼容**
- 自动显示 **HTTP 状态码、耗时（ms）**
- 自动格式化 JSON（使用 `jq`）
- 以 `bat` 高亮输出 JSON
- 永远只执行一次 `curl`（避免两次请求导致的响应污染）
- 不对响应内容进行破坏性的过滤，保证效果与
  `curl ... | jq | bat -l json`
  完全一致

`curlpj` 是一个舒适强大的"更好用的 curl"。

---

## 🧪 行为设计（Claude-Style Behavior Spec）

### 🎯 输入（Input）
任何适用于 `curl` 的参数，包括：
- URL
- `-H` 头部
- `-d` JSON body
- `-X` 请求方式
- 认证参数（Bearer Token 等）
- 任意 cURL flags

`curlpj` 不修改、不解释、不包装任何用户传入的参数。

---

### 🎯 输出（Output）

`curlpj` 在终端输出两部分：

#### ① 请求元数据（Metadata）
- 彩色 HTTP 状态码
- 请求耗时（毫秒级）

示例：
```
✔ HTTP 200 (342ms)
→ HTTP 301 (120ms)
✘ HTTP 404 (89ms)
```

颜色规则：

| 状态码 | 颜色 | 符号 |
|-------|------|------|
| 2xx | 绿色 | ✔ |
| 3xx | 黄色 | → |
| 4xx/5xx | 红色 | ✘ |

#### ② 响应 Body
- 如果是 JSON（`{` 或 `[` 开头）：用 `jq | bat -l json` 美化输出
- 否则原样输出

---

## 📦 使用示例

### 基础用法

```bash
# GET 请求
curlpj https://api.example.com/users

# POST JSON 数据
curlpj -X POST https://api.example.com/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice","email":"alice@example.com"}'

# 带认证的请求
curlpj -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.example.com/protected
```

### 高级用法

```bash
# 完整的 REST API 调试
curlpj -X PUT https://api.example.com/users/123 \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Name"}' \
  -v

# 处理数组响应
curlpj https://api.example.com/posts
# 自动识别并美化 JSON 数组

# 非 JSON 响应
curlpj https://example.com/plain-text
# 原样输出纯文本内容
```

---

## 🔧 实现原理

### 核心技术

`curlpj` 使用 `curl` 的 `-w` 参数在一次请求中同时获取响应体和元数据：

```bash
curl -s -w "\n%{http_code} %{time_total}" "$@"
```

输出格式：
```
{响应体内容}
200 0.342
```

### 数据提取流程

1. **分离元数据**（zsh-curl-pretty.plugin.zsh:7-9）
   ```bash
   local meta=${raw_output##*$'\n'}        # 获取最后一行
   local http_code=${meta%% *}             # 提取状态码
   local time_total=${meta#* }             # 提取耗时（秒）
   ```

2. **提取响应体**（zsh-curl-pretty.plugin.zsh:12）
   ```bash
   local body=${raw_output%$'\n'"$meta"}   # 移除最后一行
   ```

3. **时间转换**（zsh-curl-pretty.plugin.zsh:15-16）
   ```bash
   # 秒 → 毫秒，使用 bc 进行浮点运算
   time_ms=$(printf '%.0f' "$(echo "$time_total * 1000" | bc -l 2>/dev/null)")
   ```

4. **彩色输出**（zsh-curl-pretty.plugin.zsh:18-30）
   - 使用 ANSI 转义码设置颜色
   - 根据状态码第一位数字选择颜色和符号

5. **智能格式化**（zsh-curl-pretty.plugin.zsh:33-37）
   ```bash
   if [[ "$body" == \{* || "$body" == \[* ]]; then
     printf '%s' "$body" | jq | bat -l json
   else
     printf '%s' "$body"
   fi
   ```

---

## 📋 依赖项

`curlpj` 需要以下工具：

| 工具 | 用途 | 安装命令 |
|------|------|---------|
| `curl` | HTTP 请求 | 系统自带 |
| `jq` | JSON 格式化 | `brew install jq` |
| `bat` | 语法高亮 | `brew install bat` |
| `bc` | 浮点运算 | 系统自带（macOS/Linux） |

### 验证依赖

```bash
# 检查所有依赖是否安装
command -v curl && command -v jq && command -v bat && command -v bc
```

---

## 🚀 安装

### 作为 Oh My Zsh 插件（推荐）

1. 克隆到插件目录：
   ```bash
   git clone https://github.com/YOUR_USERNAME/zsh-curl-pretty \
     ~/.oh-my-zsh/custom/plugins/zsh-curl-pretty
   ```

2. 在 `~/.zshrc` 中启用：
   ```bash
   plugins=(... zsh-curl-pretty)
   ```

3. 重新加载配置：
   ```bash
   source ~/.zshrc
   ```

### 手动安装

直接 source 插件文件：
```bash
# 添加到 ~/.zshrc
source /path/to/zsh-curl-pretty.plugin.zsh
```

---

## 🐛 故障排除

### 问题：`bc: command not found`

**解决方案：**
```bash
# macOS
brew install bc

# Ubuntu/Debian
sudo apt-get install bc

# CentOS/RHEL
sudo yum install bc
```

### 问题：时间显示为 `0ms` 或不准确

**原因：** `bc` 未安装或计算失败

**调试：**
```bash
# 测试 bc 计算
echo "0.342 * 1000" | bc -l
# 应输出：342.000
```

### 问题：JSON 未被高亮

**原因：** `bat` 或 `jq` 未安装

**解决方案：**
```bash
brew install jq bat
```

**降级方案：** 如果不需要高亮，可以修改代码只使用 `jq`：
```bash
printf '%s' "$body" | jq
```

### 问题：非 JSON 响应被错误识别

**原因：** 响应以 `{` 或 `[` 开头但不是 JSON

**解决方案：** 当前实现使用简单的启发式判断。如需更严格的检测，可以使用：
```bash
# 测试是否为有效 JSON
if printf '%s' "$body" | jq empty 2>/dev/null; then
  # 是有效 JSON
fi
```

---

## 🎯 设计哲学

1. **单次请求原则**
   不重复发送请求，避免副作用（POST/PUT/DELETE 等）

2. **无损输出**
   响应体完全保留原始内容，不进行截断或修改

3. **参数透传**
   `"$@"` 完全传递给 `curl`，保持 100% 兼容性

4. **优雅降级**
   即使 `jq` 或 `bat` 不可用，仍能正常显示原始内容

5. **视觉优先**
   使用颜色和符号快速传达状态，减少认知负担

---

## 📝 技术备注

### 为什么使用 `printf '%s'` 而不是 `echo`？

- `echo` 可能解释转义序列（如 `\n`）
- `printf '%s'` 保证按字面值输出，不破坏原始内容

### 为什么用 `bc -l` 而不是 `awk`？

- `bc -l` 提供任意精度浮点运算
- 更可靠地处理科学计数法（如 `1.234e-03`）

### Zsh 字符串操作说明

```bash
${var##*$'\n'}     # 删除最长匹配前缀（贪婪）
${var%$'\n'*}      # 删除最短匹配后缀
${var%% *}         # 删除第一个空格及之后的内容
${var#* }          # 删除第一个空格及之前的内容
```

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 开发建议

- 保持与 `curl` 的完全兼容性
- 避免引入额外的运行时依赖
- 确保对非 JSON 响应的优雅处理
- 保持输出简洁、可读

---

## 📄 许可证

MIT License

---

## 🙏 致谢

- `curl` - 强大的 HTTP 客户端
- `jq` - JSON 处理瑞士军刀
- `bat` - 现代化的 `cat` 替代品


