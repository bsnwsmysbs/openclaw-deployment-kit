'use strict';
let nodeSetupMonitor = null;
async function nodeSetupApi(path, body = {}) {
  const response = await fetch(path, {method:'POST',headers:{'Content-Type':'application/json','X-Check-Token':session},body:JSON.stringify(body),signal:AbortSignal.timeout(25000)});
  const state = await response.json();
  if (!response.ok) throw new Error(state.error || 'NODE_SETUP_FAILED');
  return state;
}
function readRuntimeCheck(id) {
  return nodeSetupApi('/api/check', {id,installDir:installDir()});
}
function showNodeSetup(state) {
  const panel = $('#node-setup-status');
  panel.className = 'deploy-status node-setup-panel' + (state.status === 'failed' ? ' error' : state.status === 'succeeded' ? ' complete' : '');
  $('#node-setup-message').textContent = state.message || messages[state.code]?.[0] || '正在安装 Node.js LTS…';
  $('#node-setup-progress').style.width = `${state.progress || 0}%`;
  $('#node-setup-log').textContent = state.log || '等待安装日志…';
  if (state.status === 'failed') $('#node-setup-details').open = true;
}
async function monitorNodeSetup(initial) {
  if (nodeSetupMonitor) return nodeSetupMonitor;
  nodeSetupMonitor = (async () => {
    let state = initial;
    while (state.status === 'running') {
      nodeSetupBusy = true;
      showNodeSetup(state); updateSummary();
      await new Promise((resolve) => setTimeout(resolve, 1500));
      try { state = await nodeSetupApi('/api/node/status'); }
      catch {
        showNodeSetup({status:'running',message:'正在重新连接安装任务。后台安装可能仍在运行，请保留启动窗口。',log:state.log,progress:state.progress});
        // Do not unlock deployment while the background installer is unconfirmed.
      }
    }
    nodeSetupBusy = false;
    showNodeSetup(state); updateSummary();
    return state;
  })();
  try { return await nodeSetupMonitor; } finally { nodeSetupMonitor = null; }
}
async function ensureNodeSetup() {
  nodeSetupBusy = true; updateSummary();
  showNodeSetup({status:'running',message:'检测到运行环境需要安装或修复，正在启动 Node.js LTS 安装…',progress:5});
  try { return await monitorNodeSetup(await nodeSetupApi('/api/node/setup')); }
  catch (error) {
    // A timed-out submission may already have launched the installer.
    try {
      const current = await nodeSetupApi('/api/node/status');
      if (current.status === 'running') return await monitorNodeSetup(current);
    } catch {}
    nodeSetupBusy=false; updateSummary();
    const state={status:'failed',code:error.message,message:messages[error.message]?.[0] || '本地安装任务未响应，请确认检查台仍在运行后刷新查询。'};
    showNodeSetup(state); return state;
  }
}
async function recoverNodeSetup() {
  try {
    const state = await nodeSetupApi('/api/node/status');
    if (state.status === 'idle') return;
    if (state.status === 'running') {
      nodeSetupAttempted = true;
      const finished = await monitorNodeSetup(state);
      if (finished.status === 'succeeded') {
        for (const id of ['node','npm']) { const result=await readRuntimeCheck(id); results.set(id,result); updateRow(id,result); }
        updateSummary();
      }
    } else showNodeSetup(state);
  } catch { /* Page remains usable; the next explicit check reports helper errors. */ }
}
recoverNodeSetup();
