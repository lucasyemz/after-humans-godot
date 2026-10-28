export function setupWorkspace({persistNow,isBusy,getName}){
 const body=document.body,stage=document.getElementById('stage'),toggle=document.getElementById('viewMode'),size=document.getElementById('previewSize');
 const params=new URL(location.href).searchParams;
 function setPreview(active){body.classList.toggle('previewMode',active);toggle.setAttribute('aria-pressed',String(active));toggle.textContent=active?'Voltar à edição':'Prévia responsiva';document.title=(active?'Prévia':'Editor')+' · '+getName();}
 function setDevice(device){body.dataset.device=['phone','tablet'].includes(device)?device:'fluid';document.querySelectorAll('[data-device]').forEach(button=>{if(button.tagName==='BUTTON')button.setAttribute('aria-pressed',String(button.dataset.device===body.dataset.device));});}
 toggle.onclick=()=>{if(!isBusy())setPreview(!body.classList.contains('previewMode'));};
 document.querySelectorAll('button[data-device]').forEach(button=>button.onclick=()=>{if(!isBusy())setDevice(button.dataset.device);});
 document.getElementById('workspaceTitle').textContent=getName();setDevice(params.get('device'));setPreview(params.get('preview')==='1');
 const observer=new ResizeObserver(()=>{size.textContent=Math.round(stage.clientWidth)+' × '+Math.round(stage.clientHeight)+' px';stage.style.setProperty('--stage-width',stage.clientWidth+'px');});observer.observe(stage);
 document.getElementById('backToDashboard').onclick=async event=>{event.preventDefault();if(isBusy())return;if(await persistNow())location.href='./';};
}
