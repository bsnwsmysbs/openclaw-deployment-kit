'use strict';
let gatewayAccessRequest = 0;
let gatewayAccessBusy = false;
let gatewayAccessTimer;
const gatewayAccessMessages = {
  GATEWAY_ACCESS_PATH_INVALID:'安装目录无效或受保护，请核对上方目录。',
  GATEWAY_ACCESS_INSTALLATION_MISSING:'尚未找到安装，请完成部署后读取网关 Token。',
  GATEWAY_ACCESS_CONFIG_INVALID:'网关配置不存在或不符合本机访问要求，请处理配置检查项。',
  GATEWAY_ACCESS_TOKEN_MISSING:'未找到可用的网关 Token，请核对 gateway.auth.token 与认证模式。',
  GATEWAY_ACCESS_OFFLINE:'网关尚未就绪，请运行安装目录的 start-gateway.cmd 后再点击打开。',
  GATEWAY_ACCESS_OPEN_FAILED:'系统浏览器未能打开。请复制上方地址，在 OpenClaw 连接设置中填写此 Token。',
};
function syncGatewayAccessControls() {
  const busy = gatewayAccessBusy || running || deploymentBusy || nodeSetupBusy || modelKeyBusy;
  $('#refresh-gateway').disabled = busy;
  $('#open-gateway').disabled = busy || !$('#gateway-token').value;
  $('#copy-gateway-token').disabled = busy || !$('#gateway-token').value;
}
function clearGatewayAccess() {
  gatewayAccessRequest++;
  gatewayAccessBusy=false;
  $('#gateway-token').value=''; $('#gateway-address').value='';
  $('#gateway-access-message').textContent='';
  syncGatewayAccessControls();
}
async function refreshGatewayAccess(open = false) {
  const directory = installDir();
  const request = ++gatewayAccessRequest;
  gatewayAccessBusy = true; syncGatewayAccessControls();
  $('#gateway-token').value=''; $('#gateway-address').value='';
  const message = $('#gateway-access-message');
  message.className='key-message'; message.textContent='正在读取本机网关配置…';
  try {
    const access = await deployApi('/api/gateway/access', {installDir:directory});
    if (request !== gatewayAccessRequest || directory !== installDir()) return;
    $('#gateway-token').value=access.token;
    $('#gateway-address').value=access.baseUrl;
    message.textContent='已读取当前安装的网关 Token。点击打开时会自动携带认证信息。';
    if (open) {
      const opened = await deployApi('/api/gateway/open', {installDir:directory});
      if (request === gatewayAccessRequest && directory === installDir()) message.textContent=opened.message;
    }
  } catch (error) {
    if (request !== gatewayAccessRequest || directory !== installDir()) return;
    message.textContent=gatewayAccessMessages[error.message] || '读取或打开未完成，请确认检查台仍在运行后重试。';
    message.className='key-message error';
  } finally {
    if (request === gatewayAccessRequest) { gatewayAccessBusy=false; syncGatewayAccessControls(); }
  }
}
$('#refresh-gateway').addEventListener('click', () => refreshGatewayAccess());
$('#open-gateway').addEventListener('click', () => refreshGatewayAccess(true));
$('#copy-gateway-token').addEventListener('click', async () => {
  try { await navigator.clipboard.writeText($('#gateway-token').value); toast('网关 Token 已复制'); }
  catch { toast('复制失败，请选中 Token 后手动复制'); }
});
$('#install-dir').addEventListener('input', () => {
  clearTimeout(gatewayAccessTimer);
  gatewayAccessBusy=false; clearGatewayAccess();
  gatewayAccessTimer=setTimeout(() => refreshGatewayAccess(), 400);
});
syncGatewayAccessControls();
