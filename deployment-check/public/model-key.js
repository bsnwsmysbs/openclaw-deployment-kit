'use strict';
const keyMessages = {
  MODEL_KEY_FORMAT:'请输入正确的 sk- 开头的 DeepSeek API Key。',
  MODEL_KEY_BUSY:'环境安装或程序部署正在运行，请等待完成后再保存。',
  MODEL_KEY_PATH_INVALID:'安装目录无效或受保护，请核对上方目录。',
  MODEL_KEY_INSTALLATION_MISSING:'尚未找到完整安装，请先安装小龙虾；新安装可填写上方的 Key。',
  MODEL_KEY_CONFIG_INVALID:'配置文件无法解析，请先处理配置检查的失败项。',
  MODEL_KEY_PROVIDER_UNSUPPORTED:'当前安装使用的不是 DeepSeek 官方服务，请按实际服务商修改配置。',
  MODEL_KEY_CONFIG_OVERRIDE:'配置里直接指定了其他密钥。请先在 config/openclaw.json 中将 DeepSeek apiKey 改为 ${DEEPSEEK_API_KEY}，再用此入口保存。',
};
function syncModelKeyControls() {
  const busy = running || deploymentBusy || nodeSetupBusy || modelKeyBusy;
  $('#saved-model-key').disabled=busy;
  $('#save-model-key').disabled=busy;
}
$('#save-model-key').addEventListener('click', async () => {
  if (running || deploymentBusy || nodeSetupBusy || modelKeyBusy || !validPath()) return;
  const key = $('#saved-model-key').value.trim();
  const output = $('#model-key-message');
  if (!/^sk-[A-Za-z0-9_-]{8,256}$/.test(key)) { output.textContent=keyMessages.MODEL_KEY_FORMAT; output.className='key-message error'; return; }
  modelKeyBusy=true; updateSummary();
  output.textContent='正在保存密钥…'; output.className='key-message';
  try {
    const result = await deployApi('/api/model/key', {installDir:installDir(),apiKey:key});
    $('#saved-model-key').value='';
    // A changed credential invalidates the prior chat acceptance.
    manualResults.delete('chat'); $('#manual-chat').checked=false;
    $('#manual-chat').parentElement.classList.remove('checked');
    results.delete('model-config'); updateRow('model-config',{status:'pending'});
    output.textContent=result.message; output.className='key-message saved';
    const checked = await readRuntimeCheck('model-config');
    results.set('model-config',checked); updateRow('model-config',checked);
    output.textContent += checked.status === 'pass' ? ' 密钥和模型目录检查通过；实际对话仍需重启网关后验收。' : ' 密钥和模型检查尚未通过，请查看清单中的处理方法。';
    if (checked.status !== 'pass') output.className='key-message error';
  } catch (error) {
    $('#saved-model-key').value='';
    output.textContent=keyMessages[error.message] || '保存或验证没有完成，请确认检查台仍在运行；若请求中断，保存可能已完成，请重新自检。';
    output.className='key-message error';
  } finally { modelKeyBusy=false; updateSummary(); }
});
syncModelKeyControls();
$('#install-dir').addEventListener('input', () => {
  $('#saved-model-key').value='';
  $('#model-key-message').textContent='';
  $('#model-key-message').className='key-message';
});
