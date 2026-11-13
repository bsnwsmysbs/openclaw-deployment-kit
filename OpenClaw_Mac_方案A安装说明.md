# OpenClaw Mac 安装说明（方案 A：官方脚本安装）

适用场景：客户使用 Mac，不使用交付包，直接通过 OpenClaw 官方安装脚本安装。

官方参考：

- 安装文档：https://docs.openclaw.ai/install
- 入门文档：https://docs.openclaw.ai/start/getting-started
- Onboarding 引导说明：https://docs.openclaw.ai/start/wizard
- Gateway 状态命令：https://docs.openclaw.ai/cli/gateway
- Doctor 修复命令：https://docs.openclaw.ai/gateway/doctor

## 一、安装前准备

安装前请准备好：

1. 一台可以联网的 Mac。
2. 可以打开“终端”的用户账号。
3. 一个模型服务 API Key，例如 OpenAI、Anthropic、Google、Moonshot/Kimi、DeepSeek 兼容服务等。
4. 如果要长期运行，建议 Mac 不要频繁关机。

说明：

- 官方安装脚本会自动检查系统环境。
- 官方推荐 Node 24，也支持 Node 22.19+。
- 如果 Mac 没有合适的 Node，安装脚本会尝试自动安装。

## 二、打开终端

在 Mac 上打开：

```bash
应用程序 -> 实用工具 -> 终端
```

或者按 `Command + 空格`，搜索“终端”。

## 三、执行安装命令

在终端里粘贴下面命令，然后回车：

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

这个命令会做几件事：

1. 检查 Mac 系统。
2. 检查或安装 Node。
3. 安装 OpenClaw CLI。
4. 自动进入 OpenClaw 的 onboarding 引导。

如果中途要求输入 Mac 登录密码，正常输入即可。输入密码时终端可能不会显示星号，这是 macOS 的正常表现。

## 四、引导过程怎么选

OpenClaw 的引导看起来会有不少问题，但普通安装只需要理解几类选择。

### 1. 如果问是否继续

建议选择：

```text
Yes
```

或直接按回车接受默认选项。

### 2. 如果问已有配置怎么处理

如果是第一次安装，一般不会出现这个问题。

如果出现类似：

```text
Keep current values
Review and update
Reset
```

建议：

- 第一次安装：选 `Review and update` 或按默认。
- 已经能正常使用：选 `Keep current values`。
- 配坏了、想重新来：才选 `Reset`。

注意：不要随便选 `Reset`，除非明确要重置配置。

### 3. 如果问模型服务商

这里是在选择 OpenClaw 用哪个大模型。

常见选择：

| 使用的模型服务 | 建议选择 |
| --- | --- |
| OpenAI / ChatGPT / GPT API | OpenAI |
| Anthropic / Claude API | Anthropic |
| Google Gemini | Google / Gemini |
| OpenRouter | OpenRouter |
| Moonshot / Kimi | Moonshot / Kimi |
| 自建或第三方 OpenAI 兼容接口 | Custom provider / OpenAI-compatible |

如果客户已经买了某个 API，就选对应服务商。

如果不确定，先停在这一步，不要乱选，确认 API Key 属于哪家服务。

### 4. 如果要求输入 API Key

把模型服务后台复制出来的 API Key 粘贴进去，然后回车。

如果出现存储方式选择，建议普通用户选择：

```text
Paste API key now
```

如果是更严格的企业环境，可以选择环境变量或 secret reference，但这需要额外配置。

### 5. 如果问 Gateway 配置

Gateway 可以理解为 OpenClaw 在本机运行的后台服务。

普通 Mac 本机安装建议：

| 选项 | 建议 |
| --- | --- |
| Local or remote Gateway | Local |
| Host / bind address | 使用默认 |
| Port | 使用默认 |
| Auth mode | 使用默认 |

如果不懂这些问题，优先按回车接受默认值。

### 6. 如果问是否安装 daemon / background service

建议选择：

```text
Yes
```

或者安装完成后手动执行：

```bash
openclaw onboard --install-daemon
```

daemon 的作用是让 OpenClaw Gateway 在后台运行，并且 Mac 重启后可以自动启动。

### 7. 如果问 Channels

Channels 是让 OpenClaw 接入 Telegram、Slack、Discord、WhatsApp、iMessage 等聊天入口。

如果只是先把 OpenClaw 装起来，建议：

```text
Skip
```

或者选择暂不配置。

等基础安装成功后，再单独配置聊天渠道会更稳。

### 8. 如果问 Skills

Skills 是 OpenClaw 的能力包。

如果只是基础安装，可以先接受默认或跳过。

如果后续要安装 OpenClaw 七大业务场景，再把对应 skills 放到 OpenClaw/Codex 的技能目录里单独配置。

## 五、安装完成后的检查命令

安装完成后，依次执行：

```bash
openclaw --version
```

如果能显示版本号，说明 CLI 已安装。

继续执行：

```bash
openclaw gateway status
```

如果看到 Gateway 是 running / ok，说明后台服务正常。

再执行：

```bash
openclaw doctor
```

这个命令会检查配置、服务、模型、插件等状态。

如果 doctor 提示可以自动修复，可以执行：

```bash
openclaw doctor --fix
```

## 六、推荐的完整安装流程

第一次安装建议按下面顺序执行：

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
openclaw onboard --install-daemon
openclaw --version
openclaw gateway status
openclaw doctor
```

说明：

- 第一条命令安装 OpenClaw。
- 第二条命令确保引导完成并安装后台服务。
- 后三条命令用于确认安装结果。

如果第一条命令已经自动进入并完成了 onboarding，第二条命令可以不重复执行。

## 七、常见问题

### 1. 提示 openclaw: command not found

先关闭终端，重新打开，再执行：

```bash
openclaw --version
```

如果还是不行，说明 PATH 没刷新或安装未成功，需要重新检查安装日志。

### 2. Gateway 没有运行

执行：

```bash
openclaw gateway status
openclaw doctor
```

如果 doctor 给出修复建议，再执行：

```bash
openclaw doctor --fix
```

### 3. API Key 输错了

重新执行：

```bash
openclaw onboard
```

选择 review/update 配置，然后重新填写模型服务商和 API Key。

### 4. 不知道模型服务商怎么选

看 API Key 是从哪里买的：

- 从 OpenAI 后台创建的，选 OpenAI。
- 从 Anthropic 后台创建的，选 Anthropic。
- 从 Google AI Studio 创建的，选 Google/Gemini。
- 从 OpenRouter 创建的，选 OpenRouter。
- 从 Moonshot/Kimi 创建的，选 Moonshot/Kimi。
- 从其他平台创建但说兼容 OpenAI API，选 OpenAI-compatible 或 Custom provider。

### 5. 不想配置聊天软件

可以跳过 Channels。

先保证 OpenClaw Gateway 和模型能正常工作，后续再配置 Telegram、Slack、Discord 等入口。

## 八、给客户的简化口径

如果客户问“我看到很多选项怎么办”，可以这样解释：

```text
安装时大部分选项直接按回车使用默认值。
重点只需要确认三件事：
1. 选择正确的模型服务商；
2. 粘贴正确的 API Key；
3. 允许安装后台服务 daemon。
聊天渠道和 skills 可以先跳过，后面再配置。
```

## 九、验收标准

安装完成后，满足下面三项即可认为基础安装成功：

```bash
openclaw --version
openclaw gateway status
openclaw doctor
```

验收结果：

1. `openclaw --version` 能显示版本。
2. `openclaw gateway status` 显示 Gateway 正常运行。
3. `openclaw doctor` 没有阻断性错误。
