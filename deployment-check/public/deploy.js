'use strict';
let selectedPackage = null;
let uploadingPackage = false;
let deploymentTimer;
let activeJob = null;
const deploymentErrors = {
  ZIP_TOO_LARGE: '安装包超过限制，或解压后体积异常。请选择 Windows Lite 包（ZIP 最大 16 MB）。',
  ZIP_UNSAFE_PATH: '安装包包含不安全的路径，已拒绝解压。',
  ZIP_DUPLICATE_ENTRY: '安装包包含重复文件路径，请重新生成 ZIP。',
  ZIP_PACKAGE_INVALID: '不是支持的 OpenClaw Windows Lite 包，或缺少必需文件。',
  ZIP_UNTRUSTED: '安装包与本仓库源码不一致。请运行 scripts/build-package.ps1 生成当前包；已登记的旧版 ZIP 也可以直接使用。',
  DEPLOY_PATH_INVALID: '部署路径请只使用盘符、英文字母、数字、下划线和连字符，例如 C:\\OpenClawMeeting。',
  DEPLOY_DRIVE_MISSING: '目标盘符不存在，请修改上方安装目录。',
  DEPLOY_PATH_PROTECTED: '不能部署到系统、用户配置、仓库目录或链接目录。请另选独立的新目录。',
  DEPLOY_TARGET_NOT_EMPTY: '目标目录已有内容。本版不覆盖旧安装，请选择一个新的空目录。',
  DEPLOY_PORT_INVALID: '网关端口必须在 1024～65535 之间，并且不能与本检测台相同。',
  DEPLOY_PORT_BUSY: '网关端口已被占用。请更换端口，或先处理正在运行的旧网关。',
  DEPLOY_BUSY: '已有部署任务正在运行，请等待当前任务结束。',
  NODE_SETUP_BUSY: 'Node.js 环境正在安装，请等待安装和验证完成后再部署。',
  PACKAGE_NOT_FOUND: '安装包会话已失效，请重新选择 ZIP。',
  PACKAGE_SOURCE_MISSING: '仓库内的轻量版文件不完整，请重新下载完整仓库并解压后启动。',
  MODEL_KEY_FORMAT: 'DeepSeek Key 格式不正确。请核对，或留空后续配置。',
  NODE_MISSING: '还没有安装 Node.js。请先点击全面自检，检查台会自动尝试安装。',
  NODE_OLD: 'Node.js 版本过低，请先点击全面自检，检查台会自动尝试升级。',
  NPM_MISSING: 'npm 不完整，请修复系统 Node.js 安装。',
  COMMAND_FAILED: 'Node.js 或 npm 无法正常执行，请先修复运行环境。',
  DEPLOY_GATEWAY_NOT_READY: '安装脚本已结束，但网关仍未响应。请检查日志；本次部署未计为成功。',
  DEPLOY_ARTIFACTS_MISSING: '安装脚本结束后仍缺少程序文件，本次部署未计为成功。',
  DEPLOY_INSTALL_FAILED: '安装过程失败，请查看日志中的具体原因。',
  DEPLOY_PROCESS_EXITED: '安装进程提前退出，请查看日志。',
  DEPLOY_TIMEOUT: '安装超过 30 分钟，已停止任务。请检查网络后重新安装到新目录。',
  DEPLOY_REQUEST_FAILED: '安装包处理失败。请确认 ZIP 完整、目录可访问后重试。',
};
async function deployApi(path, body, binary = false) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 30000);
  try {
    const response = await fetch(path, { method: 'POST', headers: { 'X-Check-Token': session, 'Content-Type': binary ? 'application/zip' : 'application/json' }, body: binary ? body : JSON.stringify(body), signal: controller.signal });
    let data;
    try { data = await response.json(); } catch { throw new Error('HELPER_OFFLINE'); }
    if (!response.ok) throw new Error(data.error || 'DEPLOY_REQUEST_FAILED');
    return data;
  } finally { clearTimeout(timer); }
}
function syncDeploymentControls() {
  const busy = running || deploymentBusy || uploadingPackage || nodeSetupBusy || modelKeyBusy;
  $('#package-file').disabled = busy;
  $('#use-bundled').disabled = busy;
  $('#deploy-key').disabled = busy;
  $('#deploy-port').disabled = busy;
  $('#deploy-business').disabled = busy;
  $('#deploy-button').disabled = busy || !selectedPackage;
}
async function useBundledPackage() {
  if (running || deploymentBusy || uploadingPackage || nodeSetupBusy || modelKeyBusy) return;
  selectedPackage = null;
  uploadingPackage = true;
  syncDeploymentControls();
  $('#deploy-status').classList.add('hidden');
  $('#deploy-badge').className = 'badge neutral';
  $('#deploy-badge').textContent = '正在读取轻量版';
  $('#package-info').textContent = '正在准备仓库自带的轻量版…';
  try {
    const result = await deployApi('/api/packages/bundled', {});
    selectedPackage = result;
    $('#package-file').value = '';
    $('#package-info').textContent = `仓库自带 Windows Lite v${result.package.version} · OpenClaw ${result.package.openclawVersion} · ${result.package.fileCount} 个文件，无需另选 ZIP。`;
    $('#deploy-badge').className = 'badge pass';
    $('#deploy-badge').textContent = '轻量版已就绪';
    $('#deploy-button').textContent = '↥ 安装仓库自带轻量版';
  } catch (error) {
    showDeployError(error);
    $('#package-info').textContent = '轻量版未就绪，请检查仓库是否完整，或展开下方选项上传 ZIP。';
  } finally { uploadingPackage = false; syncDeploymentControls(); }
}
$('#use-bundled').addEventListener('click', useBundledPackage);
function showDeployError(error) {
  const code = error.name === 'AbortError' ? 'REQUEST_TIMEOUT' : error.message;
  const text = deploymentErrors[code] || '本地检测程序没有响应，请确认启动窗口仍在运行，刷新页面后重新查询。';
  $('#deploy-status').className = 'deploy-status error';
  $('#deploy-message').textContent = text;
  $('#deploy-badge').className = 'badge fail';
  $('#deploy-badge').textContent = '需要处理';
}
$('#package-file').addEventListener('change', async () => {
  const file = $('#package-file').files[0];
  selectedPackage = null;
  if (!file) { syncDeploymentControls(); return; }
  if (file.size > 16 * 1024 * 1024 || !file.name.toLowerCase().endsWith('.zip')) {
    showDeployError(new Error('ZIP_TOO_LARGE')); syncDeploymentControls(); return;
  }
  uploadingPackage = true; syncDeploymentControls();
  $('#deploy-badge').className = 'badge neutral';
  $('#deploy-badge').textContent = '正在校验';
  $('#package-info').textContent = `正在读取 ${file.name}…`;
  $('#deploy-status').classList.add('hidden');
  try {
    const result = await deployApi('/api/packages', file, true);
    selectedPackage = result;
    $('#deploy-button').textContent = '↥ 解压并安装所选 ZIP';
    const pkg = result.package;
    $('#package-info').textContent = `${file.name} · v${pkg.version} · ${pkg.fileCount} 个文件 · SHA256 ${pkg.sha256.slice(0, 12)}…`;
    $('#deploy-badge').textContent = '安装包已校验';
    $('#deploy-badge').className = 'badge pass';
  } catch (error) { showDeployError(error); $('#package-info').textContent = '安装包未通过校验，请重新选择。'; }
  finally { uploadingPackage = false; syncDeploymentControls(); }
});
function displayDeployment(state) {
  $('#deploy-status').className = 'deploy-status' + (state.status === 'failed' ? ' error' : state.status === 'succeeded' ? ' complete' : '');
  $('#deploy-message').textContent = (state.code && deploymentErrors[state.code]) || state.message;
  $('#deploy-progress').style.width = `${state.progress || 0}%`;
  const stageLabels = { starting: '启动安装', installer: '安装程序与业务资料', gateway: '验证网关', complete: '安装完成' };
  $('#deploy-stage').textContent = `${stageLabels[state.stage] || state.stage || ''} · ${state.progress || 0}%`;
  $('#deploy-log').textContent = state.log || '等待安装日志…';
  $('#deploy-badge').textContent = state.status === 'failed' ? '部署失败' : state.status === 'succeeded' ? '部署完成' : '正在部署';
  $('#deploy-badge').className = 'badge ' + (state.status === 'failed' ? 'fail' : state.status === 'succeeded' ? 'pass' : 'neutral');
  if (state.status === 'failed') $('#deploy-log-details').open = true;
}
async function pollDeployment(initial = false) {
  clearTimeout(deploymentTimer);
  try {
    const state = await deployApi('/api/deploy/status', {});
    if (state.status === 'idle') return;
    if (initial && !activeJob) {
      activeJob = state.jobId;
      $('#install-dir').value = state.installDir;
      results.clear(); resetManual();
    }
    displayDeployment(state);
    deploymentBusy = state.status === 'running';
    updateSummary();
    if (deploymentBusy) deploymentTimer = setTimeout(() => pollDeployment(), 1500);
    else if (!initial && state.status === 'succeeded') {
      await refreshGatewayAccess(true);
      toast('部署完成，正在自动运行全面自检');
      await runAll();
    }
  } catch (error) {
    showDeployError(error);
    // A disconnected browser must not assume that a background install stopped.
    if (deploymentBusy) deploymentTimer = setTimeout(() => pollDeployment(), 4000);
  }
}
$('#deploy-button').addEventListener('click', async () => {
  if (!selectedPackage || running || deploymentBusy || nodeSetupBusy || modelKeyBusy || !validPath()) return;
  deploymentBusy = true; updateSummary();
  clearGatewayAccess();
  $('#deploy-status').className = 'deploy-status';
  $('#deploy-message').textContent = '正在检查目标目录并解压安装包…';
  try {
    const state = await deployApi('/api/deploy', { packageId: selectedPackage.packageId, installDir: installDir(), port: Number($('#deploy-port').value), apiKey: $('#deploy-key').value.trim(), includeBusiness: $('#deploy-business').checked });
    $('#deploy-key').value = '';
    activeJob = state.jobId;
    results.clear(); resetManual();
    items.forEach(([id]) => updateRow(id, {status:'pending'}));
    displayDeployment(state);
    deploymentTimer = setTimeout(() => pollDeployment(), 1000);
  } catch (error) {
    $('#deploy-key').value = '';
    showDeployError(error);
    // Query status after an uncertain response, preventing a duplicate install.
    try {
      const state = await deployApi('/api/deploy/status', {});
      deploymentBusy = state.status === 'running';
      if (deploymentBusy) { activeJob=state.jobId; displayDeployment(state); deploymentTimer=setTimeout(() => pollDeployment(),1500); }
    } catch { deploymentBusy = false; }
  } finally { updateSummary(); }
});
async function initializeDeployment() {
  syncDeploymentControls();
  await useBundledPackage();
  await pollDeployment(true);
  await refreshGatewayAccess();
}
window.addEventListener('DOMContentLoaded', initializeDeployment, {once:true});
