'use strict';

const $ = (selector) => document.querySelector(selector);
const session = $('meta[name="check-session"]').content;
const groups = [
  { title: '系统与运行环境', description: '确认这台电脑具备安装条件', items: [
    ['system', 'Windows 系统', '检查 64 位系统与处理器架构。'],
    ['disk', '安装盘可用空间', '建议预留 20 GB，低于 8 GB 将提示处理。'],
    ['powershell', 'PowerShell 7', '确认默认已安装的 PowerShell 7 可以正常运行。'],
    ['node', 'Node.js 运行环境', '检查 ≥ 24.16.0；缺失或过旧时自动通过 winget 安装。'],
    ['npm', 'npm 包管理器', '实际执行 npm，确认依赖安装工具可用。'],
  ] },
  { title: '网络与程序安装', description: '确认依赖能下载、程序已就位', items: [
    ['npm-network', 'OpenClaw 下载源', '检查下载源能否提供 openclaw@2026.6.1。'],
    ['model-network', 'DeepSeek 网络连通', '检查模型接口可达性，此项不验证密钥。'],
    ['installation', 'OpenClaw 安装文件', '检查启动入口、配置文件和安装版本。'],
  ] },
  { title: '配置与服务连接', description: '确认配置正确，网页与模型可连接', items: [
    ['config', '本机网关配置', '检查配置格式、访问端口与认证设置。'],
    ['gateway', 'Gateway 网关与页面', '确认本机端口可访问，并返回 OpenClaw 页面。'],
    ['model-config', 'API 密钥与模型名称', '通过官方模型目录验证密钥和当前模型，不生成对话。'],
  ] },
  { title: '业务能力与日常使用', description: '确认资料、工具与启动入口准备完成', items: [
    ['skills', '七大业务场景', '检查七个 Skill 文件与 OpenClaw 的加载状态。'],
    ['workspace', '助手说明与使用指引', '检查 AGENTS、SOUL 和工作区导航文件。'],
    ['workbench', '桌面龙虾工作台', '检查当前用户的输入资料与输出成果目录。'],
    ['docx', 'Word 导出工具', '检查 DOCX 导出脚本是否存在，实际导出在下方验收。'],
    ['autostart', '当前用户登录自启', '检查启动文件夹入口是否指向本次安装目录。'],
  ] },
];
const manual = [
  { id: 'chat', label: '实际对话：打开 OpenClaw，输入「功能列表」并提问，确认能正常回复。', requires: ['gateway', 'model-config'] },
  { id: 'file', label: '资料与导出：放入一份测试资料，生成 Word 报告，并用 WPS / Office 打开确认。', requires: ['workbench', 'docx'] },
  { id: 'reboot', label: '重启验收：重启电脑并登录同一用户，确认无需手动启动即可打开 OpenClaw。', requires: ['autostart'] },
];
const items = groups.flatMap((g) => g.items);
const results = new Map();
const manualResults = new Set();
let running = false;
let deploymentBusy = false;
let nodeSetupBusy = false;
let modelKeyBusy = false;
let nodeSetupAttempted = false;
let stopRequested = false;
let lastRun = null;
let toastTimer;
const labels = { pending: '等待检查', running: '正在检查', pass: '检查通过', fail: '需要处理', warn: '待确认' };
const messages = {
  SYSTEM_OK: ['64 位 Windows 系统，符合部署条件。'],
  SYSTEM_X64_REQUIRED: ['当前系统不是 64 位 Windows。', '请使用 Windows x64 电脑部署当前交付版本。'],
  SYSTEM_ARM_UNTESTED: ['检测到 ARM 系统，当前交付版尚未验证。', '需要先验证 Node、OpenClaw 及其依赖的 ARM 兼容性。'],
  DRIVE_MISSING: ['安装盘不存在或尚未就绪。', '将上方目录改成实际存在的盘符，例如 C:\\OpenClawMeeting，再重新检查。'],
  DISK_LOW: ['可用空间低于 8 GB，请先处理。', '清理空间或改用其他安装盘，再重新检查。'],
  DISK_RECOMMENDED: ['空间超过 8 GB，但尚未达到建议的 20 GB。', '资料、依赖和日志会持续占用空间，建议留出更多余量。'],
  DISK_OK: ['可用空间达到建议值。'],
  PWSH_MISSING: ['未找到 PowerShell 7。', '安装 Microsoft PowerShell 7 后，关闭并重新启动本检测台。', 'winget install --id Microsoft.PowerShell --exact'],
  PWSH_OLD: ['PowerShell 版本不满足要求。', '请升级到 PowerShell 7。'],
  PWSH_OK: ['PowerShell 7 可以正常执行。'],
  NODE_MISSING: ['未找到 Node.js。', '自检会自动尝试安装 Node.js LTS；若失败，可手动执行下面命令后重试。', 'winget install --id OpenJS.NodeJS.LTS --exact --source winget'],
  NODE_OLD: ['Node.js 版本低于 24.16.0。', '自检会自动尝试安装符合要求的 LTS 版本；若失败，可手动执行下面命令后重试。', 'winget install --id OpenJS.NodeJS.LTS --exact --source winget --force'],
  NODE_OK: ['Node.js 版本符合要求。'],
  NODE_SETUP_FAILED: ['Node.js 自动安装失败。', '展开环境安装日志，检查网络和权限后重试。'],
  NODE_SETUP_TIMEOUT: ['Node.js 安装超过 15 分钟。', '检查网络和安装日志，确认旧任务已结束后重试。'],
  NODE_SETUP_VERIFY_FAILED: ['安装结束后 Node.js 或 npm 仍未通过验证。', '检查 PATH 中是否存在旧版本，必要时重启电脑后重试。'],
  NODE_WINGET_MISSING: ['未找到 winget，无法自动安装 Node.js。', '从微软商店安装或更新“应用安装程序”，或到 nodejs.org 安装 Node.js LTS（包含 npm）。'],
  NODE_SETUP_BUSY: ['其他检查台正在安装 Node.js。', '等待已有任务结束，再重试检查。'],
  NODE_SETUP_DEPLOY_BUSY: ['OpenClaw 正在安装，暂不能更改 Node.js。', '等待当前部署结束后重试。'],
  NPM_MISSING: ['Node.js 的 npm 组件不完整。', '修复或重新安装官方 Node.js（包含 npm），然后重新启动检测台。'],
  NPM_OK: ['npm 已实际执行并返回版本。'],
  NPM_NETWORK_FAILED: ['OpenClaw 下载源暂不可用。', '检查网络、代理和企业网络限制，然后重试。'],
  NPM_PACKAGE_INVALID: ['下载源返回的版本信息不符合预期。', '先确认镜像源是否正常同步 openclaw@2026.6.1。'],
  NPM_NETWORK_OK: ['下载源可访问，已找到固定版本。'],
  MODEL_NETWORK_OK: ['DeepSeek 接口可达。', '未携带密钥时返回 HTTP 401 / 403 也能证明网络可达，密钥是否有效由后续检查判断。'],
  MODEL_NETWORK_FAILED: ['DeepSeek 接口当前不可用。', '确认可以访问 api.deepseek.com；也可能是服务限流，请稍后重试。'],
  INSTALLATION_MISSING: ['安装文件尚未齐全，或上方目录不正确。', '先确认安装目录，再解压当前 Windows Lite 交付包，运行其中的 install.cmd。'],
  INSTALLATION_VERSION: ['已安装，但与交付基准 2026.6.1 不一致。', '如果是有意升级，请另外验证七大场景与导出工具的兼容性。'],
  INSTALLATION_OK: ['安装入口和固定版本文件已就位。'],
  CONFIG_MISSING: ['还没有找到配置文件。', '先完成 OpenClaw 安装，并确认上方目录指向正确的安装位置。'],
  CONFIG_INVALID: ['配置文件无法解析为 JSON。', '检查 config\\openclaw.json 的格式，或从已知可用的备份恢复。'],
  CONFIG_PORT_INVALID: ['网关端口未配置或超出有效范围。', '请将 gateway.port 设置为 1～65535 之间的有效端口，默认 18789。'],
  CONFIG_TOKEN_MISSING: ['网关认证令牌未设置。', '请检查 gateway.auth.token；检测报告不会展示令牌内容。'],
  CONFIG_BIND: ['当前网关未按本机模式配置。', '本次验收基准是 gateway.bind=loopback；如果有多设备访问需求，需要另行验收。'],
  CONFIG_OK: ['配置可以解析，本机端口与认证设置齐全。'],
  GATEWAY_OFFLINE: ['Gateway 尚未启动，或端口没有响应。', '运行安装目录中的 start-gateway.cmd，等待启动后点击单项重试。', () => `"${installDir()}\\start-gateway.cmd"`],
  GATEWAY_WRONG_SERVICE: ['端口有响应，但无法确认是 OpenClaw 页面。', '检查端口是否被其他程序占用，并查看安装目录中的 logs 日志。'],
  GATEWAY_OK: ['已收到 OpenClaw 网页响应。', '此项验证网页可访问，实际模型对话仍需在使用验收中确认。'],
  MODEL_CUSTOM_PROVIDER: ['当前使用自定义模型服务，需人工核对。', '本版只向 DeepSeek 官方接口验证密钥，不会将密钥发送到其他服务地址。请在 OpenClaw 中实际对话验证。'],
  MODEL_KEY_MISSING: ['没有找到可用于验证的 DeepSeek 密钥。', '运行安装目录内的 Key 配置工具，配置后重试。本版支持启动脚本、环境变量与直接配置的密钥。', () => `pwsh -NoProfile -ExecutionPolicy Bypass -File "${installDir()}\\tools\\set-deepseek-key.ps1" -InstallDir "${installDir()}"`],
  MODEL_KEY_REJECTED: ['DeepSeek 官方接口拒绝了当前密钥。', '核对密钥是否填错、已失效或被禁用，再使用 Key 配置工具更新。'],
  MODEL_API_FAILED: ['模型接口验证未成功。', '检查账号与服务状态；HTTP 429 通常表示限流，稍后重试。'],
  MODEL_UNAVAILABLE: ['默认模型不在该账号当前可用的模型目录中。', '请将 OpenClaw 默认模型改为下方可用的模型之一，然后重试。'],
  MODEL_CONFIG_OK: ['密钥验证通过，默认模型在官方目录中。', '本项仅查询模型目录，不生成内容，也不验证余额或实际对话能力。'],
  SKILLS_MISSING: ['未找到全部七个业务 Skill。', '检查是否安装了业务增强版。如果选了基础版，这项缺失符合基础版设计；当前清单以七大场景版为验收目标。'],
  SKILLS_PRESENT: ['七个 Skill 文件存在，加载状态尚待确认。', '仅有文件不足以证明 OpenClaw 已加载。请在 OpenClaw 中检查技能状态，并用「功能列表」验证。'],
  SKILLS_READY: ['OpenClaw 已发现七个业务 Skill，且全部就绪。'],
  SKILLS_NOT_READY: ['OpenClaw 的七个业务 Skill 未全部就绪。', '查看下方缺失或未就绪的技能，在 OpenClaw 技能管理中检查路径和依赖。'],
  WORKSPACE_MISSING: ['助手说明或工作区导航文件缺失。', '检查安装是否完成，也可以使用交付包的工作区挂载工具补齐。'],
  WORKSPACE_OK: ['助手说明、业务规则与导航文件齐全。'],
  WORKBENCH_MISSING: ['当前用户桌面没有完整的龙虾工作台。', '确认安装时使用的是当前用户。工作台必须有 01-输入资料 和 02-输出成果 目录。'],
  WORKBENCH_OK: ['当前用户桌面的输入与输出目录齐全。'],
  DOCX_MISSING: ['没有找到 Word 导出工具。', '请使用包含 tools\\export-docx.ps1 的交付包安装或补齐工具。'],
  DOCX_PRESENT: ['DOCX 导出脚本已安装。', '脚本存在不代表已完成导出验收；请在下方用一份资料实际生成并打开 Word 文件。'],
  AUTOSTART_OK: ['当前用户启动文件夹中有正确的启动入口。', '实际重启后的运行情况，仍需完成下方重启验收。'],
  AUTOSTART_WRONG_PATH: ['登录自启入口指向其他安装目录。', '核对旧安装残留，并用当前安装目录中的 enable-autostart.ps1 重新配置。'],
  AUTOSTART_UNCONFIRMED: ['未找到本交付包的登录自启入口。', '如果使用计划任务或 Windows 服务，请人工核验。本版自动识别的是当前交付包的启动文件夹方案。', () => `pwsh -NoProfile -ExecutionPolicy Bypass -File "${installDir()}\\enable-autostart.ps1"`],
  COMMAND_TIMEOUT: ['命令执行超时。', '对应程序可能无响应；检查后点击重试，其他项目仍可继续检查。'],
  COMMAND_FAILED: ['对应程序未能正常执行。', '尝试修复或重新安装该组件，再点击重试。'],
  NETWORK_UNREACHABLE: ['网络连接失败或超过 8 秒未响应。', '检查网络、代理、证书或企业网络限制，然后重试。'],
  INVALID_PATH: ['安装目录格式不正确。', '请填写完整的本地英文 Windows 路径，例如 D:\\OpenClawMeeting。'],
  CHECK_ERROR: ['这项检查没有完成。', '检查安装目录和文件访问权限后重试；本项不会被计为通过。'],
  HELPER_OFFLINE: ['本地检测程序未连接或没有响应。', '确认 start.cmd 的窗口仍在运行；关闭旧窗口后重新打开 start.cmd，再刷新页面。'],
  REQUEST_TIMEOUT: ['本项检查超过 25 秒未返回，已标记为失败。', '本地检测程序可能正在等待系统响应，稍后单项重试；必要时重新启动检测台。'],
};

function installDir() { return $('#install-dir').value.trim().replace(/\\+$/, ''); }
function make(tag, className = '', text = '') {
  const element = document.createElement(tag);
  element.className = className;
  if (text) element.textContent = text;
  return element;
}
function render() {
  let number = 0;
  groups.forEach((group, index) => {
    const section = make('section', 'check-group');
    const heading = make('div', 'group-heading');
    heading.append(make('span', 'group-number', String(index + 1).padStart(2, '0')), make('h3', '', group.title), make('p', '', group.description));
    const progress = make('span', 'group-progress', `0 / ${group.items.length}`);
    progress.id = `group-progress-${index}`;
    heading.append(progress);
    section.append(heading);
    group.items.forEach(([id, title, description]) => {
      const row = make('article', 'check-row');
      row.id = `check-${id}`;
      row.dataset.status = 'pending';
      const main = make('div', 'check-main');
      const icon = make('span', 'check-icon', '');
      icon.setAttribute('aria-hidden', 'true');
      const info = make('div', 'check-info');
      const h4 = make('h4', '', title);
      h4.append(make('span', 'step-label', `CHECK ${String(++number).padStart(2, '0')}`));
      const desc = make('p', 'check-description', description);
      info.append(h4, desc);
      const state = make('span', 'check-state', '等待检查');
      const actions = make('div', 'row-actions');
      const detailButton = make('button', '', '详情');
      detailButton.dataset.action = 'detail';
      detailButton.setAttribute('aria-expanded', 'false');
      detailButton.setAttribute('aria-controls', `detail-${id}`);
      detailButton.setAttribute('aria-label', `${title}：查看详情`);
      const retry = make('button', '', '检查');
      retry.dataset.action = 'retry';
      retry.setAttribute('aria-label', `${title}：单项检查`);
      detailButton.addEventListener('click', () => {
        const detail = $(`#detail-${id}`);
        const open = detail.classList.toggle('hidden');
        detailButton.setAttribute('aria-expanded', String(!open));
      });
      retry.addEventListener('click', () => runSingle(id));
      actions.append(detailButton, retry);
      main.append(icon, info, state, actions);
      const detail = make('div', 'check-details hidden');
      detail.id = `detail-${id}`;
      detail.append(make('p', '', description), make('p', '', '点击「检查」即可读取这台电脑的实际状态。'));
      row.append(main, detail);
      section.append(row);
    });
    $('#groups').append(section);
  });
  manual.forEach((item) => {
    const label = make('label', 'manual-check');
    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.id = `manual-${item.id}`;
    checkbox.disabled = true;
    checkbox.addEventListener('change', () => {
      if (checkbox.checked) manualResults.add(item.id); else manualResults.delete(item.id);
      label.classList.toggle('checked', checkbox.checked);
      updateSummary();
    });
    label.append(checkbox, make('span', '', item.label));
    $('#manual-checks').append(label);
  });
  $('#total-count').textContent = String(items.length + manual.length);
  $('#check-count').textContent = `${items.length} 项自动检查`;
}

function updateRow(id, result) {
  const row = $(`#check-${id}`);
  row.dataset.status = result.status;
  row.querySelector('.check-icon').textContent = { pass: '✓', fail: '!', warn: '!', pending: '', running: '' }[result.status];
  row.querySelector('.check-state').textContent = labels[result.status];
  const description = messages[result.code] || [items.find((item) => item[0] === id)[2]];
  row.querySelector('.check-description').textContent = description[0] + (result.detail ? ` · ${result.detail}` : '');
  if (result.status !== 'running') {
    const detail = $(`#detail-${id}`);
    detail.replaceChildren();
    detail.append(make('p', 'detail-title', description[0]));
    if (description[1]) detail.append(make('p', '', description[1]));
    if (result.detail) detail.append(make('p', '', `检测信息：${result.detail}`));
    if (result.data?.availableModels?.length) detail.append(make('p', '', `当前可用模型：${result.data.availableModels.join('、')}`));
    if (description[2]) {
      const command = typeof description[2] === 'function' ? description[2]() : description[2];
      const commandRow = make('div', 'command-row');
      const copy = make('button', '', '复制命令');
      copy.addEventListener('click', async () => {
        try { await navigator.clipboard.writeText(command); toast('命令已复制，请按需在 CMD 中执行'); }
        catch { toast('复制失败，请选中命令后手动复制'); }
      });
      commandRow.append(make('code', '', command), copy);
      detail.append(commandRow, make('p', '', 'Node.js/npm 缺失或过旧时，自检会自动尝试安装；其他命令需手动执行。'));
    }
    if (result.data?.url) {
      const link = make('a', 'button secondary', '打开 OpenClaw ↗');
      link.href = result.data.url;
      link.target = '_blank'; link.rel = 'noopener noreferrer';
      detail.append(link);
    }
    if (result.checkedAt) detail.append(make('p', '', `检查时间：${new Date(result.checkedAt).toLocaleString('zh-CN')}`));
    if (result.status === 'fail') {
      detail.classList.remove('hidden');
      row.querySelector('[data-action=detail]').setAttribute('aria-expanded', 'true');
    }
    row.querySelector('[data-action=retry]').textContent = '重试';
  }
}

function updateSummary() {
  const all = [...results.values()];
  const pass = all.filter((r) => r.status === 'pass').length + manualResults.size;
  const fail = all.filter((r) => r.status === 'fail').length;
  const warn = all.filter((r) => r.status === 'warn').length;
  const total = items.length + manual.length;
  const complete = all.filter((r) => !['running', 'pending'].includes(r.status)).length;
  const percent = Math.round(pass / total * 100);
  $('#pass-count').textContent = $('#success-count').textContent = String(pass);
  $('#fail-count').textContent = String(fail);
  $('#review-count').textContent = String(warn + manual.length - manualResults.size);
  $('#progress-percent').textContent = `${percent}%`;
  $('#progress-fill').style.width = `${percent}%`;
  const overall = $('#overall-status');
  overall.className = 'badge ' + (fail ? 'fail' : pass === total ? 'pass' : warn || complete ? 'warn' : 'neutral');
  overall.textContent = running ? '正在自检' : fail ? '存在阻塞' : pass === total ? '验收完成' : complete === items.length ? (warn ? '存在待确认项' : '待使用验收') : complete ? '部分已检查' : '尚未检查';
  $('#progress-note').textContent = running ? `正在检查，第 ${Math.min(complete + 1, items.length)} / ${items.length} 项。遇到失败也会继续排查。` : fail ? `发现 ${fail} 项需要处理，展开红色项目查看方法。` : complete === items.length ? '自动检查已结束，请处理待确认项并完成使用验收。' : complete ? `已完成 ${complete} 项自动检查，可继续检查其余项目。` : '准备好后，点击「开始全面自检」。';
  groups.forEach((group, index) => {
    $(`#group-progress-${index}`).textContent = `${group.items.filter(([id]) => results.get(id)?.status === 'pass').length} / ${group.items.length}`;
  });
  manual.forEach((item) => {
    const enabled = item.requires.every((id) => ['pass', 'warn'].includes(results.get(id)?.status));
    const checkbox = $(`#manual-${item.id}`);
    checkbox.disabled = running || nodeSetupBusy || deploymentBusy || modelKeyBusy || !enabled;
    checkbox.title = enabled ? '完成实际操作后再勾选' : '先完成相关自动检查并处理失败项';
    if (!enabled && manualResults.has(item.id)) {
      manualResults.delete(item.id);
      checkbox.checked = false;
      checkbox.parentElement.classList.remove('checked');
      queueMicrotask(updateSummary);
    }
  });
  $('#export-report').disabled = !complete;
  document.querySelectorAll('[data-action=retry]').forEach((button) => { button.disabled = running || deploymentBusy || nodeSetupBusy || modelKeyBusy; });
  $('#install-dir').disabled = running || deploymentBusy || nodeSetupBusy || modelKeyBusy;
  $('#run-all').disabled = deploymentBusy || modelKeyBusy || (nodeSetupBusy && !running);
  if (typeof syncDeploymentControls === 'function') syncDeploymentControls();
  if (typeof syncModelKeyControls === 'function') syncModelKeyControls();
  if (typeof syncGatewayAccessControls === 'function') syncGatewayAccessControls();
  $('#run-all').innerHTML = running ? '<span>◷</span> 完成本项后暂停' : '<span>▷</span> ' + (complete ? '重新全面自检' : '开始全面自检');
}

function validPath() {
  if (!/^[A-Za-z]:\\[\x20-\x7E]+$/.test(installDir()) || /[<>"|?*]/.test(installDir()) || installDir().slice(2).includes(':')) {
    notice('请填写完整的本地英文安装路径，例如 D:\\OpenClawMeeting。', true);
    $('#install-dir').focus();
    return false;
  }
  return true;
}
async function check(id) {
  const pending = { status: 'running' };
  results.set(id, pending); updateRow(id, pending); updateSummary();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 25000);
  let result;
  try {
    const response = await fetch('/api/check', {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Check-Token': session },
      body: JSON.stringify({ id, installDir: installDir() }), signal: controller.signal,
    });
    if (!response.ok) throw new Error('HELPER_OFFLINE');
    result = await response.json();
    if (!['pass', 'fail', 'warn'].includes(result.status)) throw new Error('HELPER_OFFLINE');
    clearTimeout(timer);
    if (['node', 'npm'].includes(id) && result.status === 'fail' && !nodeSetupAttempted && ['NODE_MISSING','NODE_OLD','NPM_MISSING','COMMAND_FAILED','COMMAND_TIMEOUT','CHECK_ERROR'].includes(result.code)) {
      nodeSetupAttempted = true;
      const state = await ensureNodeSetup();
      if (state.status === 'succeeded') {
        for (const runtimeId of ['node', 'npm']) {
          const verified = await readRuntimeCheck(runtimeId);
          results.set(runtimeId, verified); updateRow(runtimeId, verified);
          if (runtimeId === id) result = verified;
        }
      } else result = { status:'fail', code:state.code || 'NODE_SETUP_FAILED', detail:state.message, checkedAt:new Date().toISOString() };
    }
    $('#connection').classList.remove('offline');
    $('#connection').innerHTML = '<i></i> 本地检测程序已连接';
  } catch (error) {
    result = { status: 'fail', code: error.name === 'AbortError' ? 'REQUEST_TIMEOUT' : 'HELPER_OFFLINE', checkedAt: new Date().toISOString() };
    $('#connection').classList.add('offline');
    $('#connection').innerHTML = '<i></i> 本地检测程序连接异常';
  } finally { clearTimeout(timer); }
  results.set(id, result); updateRow(id, result);
  lastRun = new Date();
  $('#last-run').textContent = `最近检查：${lastRun.toLocaleString('zh-CN')}`;
  updateSummary();
  return result;
}
function resetManual() {
  manualResults.clear();
  manual.forEach(({ id }) => {
    const checkbox = $(`#manual-${id}`);
    checkbox.checked = false;
    checkbox.parentElement.classList.remove('checked');
  });
}
async function runAll() {
  if (deploymentBusy || modelKeyBusy) return;
  if (running) {
    stopRequested = true;
    notice('已请求暂停。当前检查结束后暂停，其余项目保留为等待检查。');
    return;
  }
  if (nodeSetupBusy) return;
  if (!validPath()) return;
  running = true; stopRequested = false; nodeSetupAttempted = false; results.clear(); resetManual();
  items.forEach(([id]) => {
    updateRow(id, { status: 'pending' });
    $(`#detail-${id}`).classList.add('hidden');
    $(`#check-${id} [data-action=detail]`).setAttribute('aria-expanded', 'false');
  });
  notice('正在逐项检查。Node.js/npm 缺失、过旧或无法运行时会自动尝试安装；若弹出系统授权窗口，请允许安装。单项失败后会继续排查。');
  updateSummary();
  try {
    for (const [id] of items) {
      if (stopRequested) break;
      const result = await check(id);
      if (result.code === 'HELPER_OFFLINE' || result.code === 'REQUEST_TIMEOUT') {
        notice('本地检测程序连接异常，已暂停后续检查。请确认启动窗口仍在运行，再重试。', true);
        stopRequested = true;
        break;
      }
    }
  } finally { running = false; updateSummary(); }
  if (!stopRequested) {
    const failed = [...results.values()].filter((r) => r.status === 'fail').length;
    notice(failed ? `本轮检查完成：${failed} 项失败，已标红并展开处理方法。修复后可单项重试。` : '本轮自动检查完成。请核对待确认项，并完成下方三项使用验收。', !!failed);
  }
}
async function runSingle(id) {
  if (running || deploymentBusy || nodeSetupBusy || modelKeyBusy || !validPath()) return;
  running = true;
  nodeSetupAttempted = false;
  // A changed prerequisite invalidates its prior manual acceptance.
  manual.filter((item) => item.requires.includes(id)).forEach((item) => {
    manualResults.delete(item.id);
    $(`#manual-${item.id}`).checked = false;
    $(`#manual-${item.id}`).parentElement.classList.remove('checked');
  });
  try { await check(id); } finally { running = false; updateSummary(); }
}
function notice(text, error = false) {
  const element = $('#run-notice');
  element.textContent = text;
  element.className = `notice${error ? ' error' : ''}`;
}
function toast(text) {
  clearTimeout(toastTimer);
  $('#toast').textContent = text; $('#toast').classList.remove('hidden');
  toastTimer = setTimeout(() => $('#toast').classList.add('hidden'), 2600);
}
function exportReport() {
  if (![...results.values()].some((r) => !['running', 'pending'].includes(r.status))) { toast('请先完成至少一项检查'); return; }
  const lines = ['OpenClaw Windows 部署检查报告', `导出时间：${new Date().toLocaleString('zh-CN')}`, `安装目录：${installDir()}`, '验收基准：PowerShell 7 / Node >= 24.16.0 / OpenClaw 2026.6.1 / 七大场景版', ''];
  groups.forEach((group) => {
    lines.push(group.title);
    group.items.forEach(([id, title]) => {
      const result = results.get(id);
      lines.push(`[${labels[result?.status] || '尚未检查'}] ${title}`);
      if (result?.code) {
        const message = messages[result.code] || [];
        lines.push(`  ${message[0] || result.code}`);
        if (result.detail) lines.push(`  信息：${result.detail}`);
        if (message[1]) lines.push(`  建议：${message[1]}`);
        if (result.checkedAt) lines.push(`  检查时间：${new Date(result.checkedAt).toLocaleString('zh-CN')}`);
      }
    });
    lines.push('');
  });
  lines.push('人工使用验收（用户确认）');
  manual.forEach((item) => lines.push(`[${manualResults.has(item.id) ? '用户已确认' : '尚未确认'}] ${item.label}`));
  lines.push('', '说明：结果仅代表检测当时的状态。模型检查仅查询官方模型目录，不生成对话、不验证余额。', '技能文件存在、导出脚本存在和自启入口存在，均不替代实际操作验收。本报告不包含 API Key 或网关令牌。');
  const blob = new Blob(['\uFEFF' + lines.join('\r\n')], { type: 'text/plain;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  const today = new Date();
  const localDate = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
  link.href = url; link.download = `OpenClaw部署检查-${localDate}.txt`;
  link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  toast('检查报告已导出');
}
$('#run-all').addEventListener('click', runAll);
$('#export-report').addEventListener('click', exportReport);
$('#sidebar-report').addEventListener('click', exportReport);
$('#install-dir').addEventListener('input', () => {
  results.clear(); resetManual();
  items.forEach(([id]) => updateRow(id, { status: 'pending' }));
  lastRun = null; $('#last-run').textContent = '检查结果仅代表当前检测时间的状态';
  notice('安装目录已改变，旧检查结果已清空。请重新自检。');
  updateSummary();
});
render(); updateSummary();
