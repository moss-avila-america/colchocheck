import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.10';
const $=id=>document.getElementById(id);
const config=window.CC_CONFIG||{};
const goodConfig=!!(config.url&&config.publishableKey&&!config.url.includes('TU_PROYECTO'));
const EMAIL_DOMAIN='users.colchocheck.example.com';
let masterDraft=null, masterUsersDraft=[];
let sb=null, me=null, profile=null, tabs='home', data={profiles:[],branches:[],sales:[],assignments:[],visits:[],breaks:[],reports:[],closings:[],warranties:[],models:[],user_imports:[]};
let stream=null, photoBlob=null, photoAction=null, geolocation=null, lastPhotoAt=null, poll=null, channel=null;
const isManager=()=>['admin','ejecutivo','supervisor'].includes(profile?.role);
const isLeader=()=>['admin','ejecutivo','direccion','gerencia'].includes(profile?.role);
const isAdmin=()=>profile?.role==='admin';
const isSupervisor=()=>profile?.role==='supervisor';
const canExport=()=>profile?.role!=='promotor';
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','"':'&quot;'}[c]));
const isoDay=()=>new Date(Date.now()-new Date().getTimezoneOffset()*60000).toISOString().slice(0,10);
const month=()=>isoDay().slice(0,7);
const fmt=v=>v?new Date(v).toLocaleString('es-MX',{dateStyle:'short',timeStyle:'short'}):'—';
const duration=(a,b)=>a?Math.max(0,Math.round((new Date(b||Date.now())-new Date(a))/60000)):0;
const hm=v=>Math.floor(v/60)+' h '+String(v%60).padStart(2,'0')+' min';
const uid=()=>crypto.randomUUID();
const badge=s=>'<span class="pill">'+esc(s)+'</span>';
const branchName=code=>{let b=data.branches.find(x=>x.code===code);return b?'#'+esc(b.code)+' · '+esc(b.name):esc(code)};
const person=id=>data.profiles.find(p=>p.id===id);
const textId=id=>{let p=person(id);return p?esc(p.full_name):String(id||'').slice(0,8)};
const sopts=(items,fn)=>items.map(fn).join('');
const byDate=(a,b)=>new Date(b.in_at||b.created_at)-new Date(a.in_at||a.created_at);
const mm=(txt,err=false)=>{let el=$('message');el.textContent=String(txt);el.className='notice'+(err?' error':' success');clearTimeout(mm.t);mm.t=setTimeout(()=>el.classList.add('hidden'),5600)};
const error=e=>{console.error(e);mm(e?.message||String(e),true)};
const view=(name)=>{tabs=name;document.querySelectorAll('.tabs button').forEach(b=>b.classList.toggle('active',b.dataset.tab===name));document.querySelectorAll('.section').forEach(e=>e.classList.toggle('active',e.id==='tab-'+name));render()};
const options=(arr,k,v)=>'<option value="">Seleccionar...</option>'+arr.map(x=>'<option value="'+esc(x[k])+'">'+esc(v(x))+'</option>').join('');
const rpc=async(name,args)=>{const r=await sb.rpc(name,args);if(r.error)throw r.error;return r.data};
function roleName(v){return {admin:'Administrador',direccion:'Dirección',gerencia:'Gerencia',ejecutivo:'Ejecutivo',supervisor:'Supervisor',promotor:'Promotor'}[v]||v}
function closeModal(){if(stream){stream.getTracks().forEach(t=>t.stop());stream=null}photoBlob=null;photoAction=null;geolocation=null;$('modalRoot').innerHTML=''}
function selectTabAndRefresh(tab){view(tab);refresh()}
function loginDisplay(){ window.CC_BOOT_READY?.(); $('login').classList.remove('hidden');$('app').classList.add('hidden');$('logout').classList.add('hidden');$('identity').textContent='Control de asistencia & cobertura'}
async function boot(){
 if(!goodConfig){$('setup').classList.remove('hidden');window.CC_BOOT_READY?.();return}
 sb=createClient(config.url,config.publishableKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:false}});
 const {data:{session},error:sessionError}=await Promise.race([
   sb.auth.getSession(),
   new Promise((_,reject)=>setTimeout(()=>reject(new Error('No fue posible recuperar la sesión. Comprueba tu conexión y vuelve a intentar.')),10000))
 ]);
 if(sessionError)throw sessionError;
 if(session)await initUser(session.user);else loginDisplay();
 sb.auth.onAuthStateChange((ev,session)=>{if(ev==='SIGNED_OUT'){me=null;profile=null;clearInterval(poll);poll=null;loginDisplay()}});
}
async function initUser(authUser){
 me=authUser;
 const r=await sb.from('cc_profiles').select('*').eq('id',me.id).single();
 if(r.error){throw new Error('No se pudo verificar tu perfil. Revisa tu conexión e inténtalo nuevamente.')}
 if(!r.data?.active){await sb.auth.signOut();loginDisplay();mm('Cuenta no habilitada. Contacta al administrador.',true);return}
 profile=r.data;
 $('login').classList.add('hidden');$('setup').classList.add('hidden');$('app').classList.remove('hidden');$('logout').classList.remove('hidden');window.CC_BOOT_READY?.();
 $('greeting').textContent='Hola, '+profile.full_name.split(' ')[0];
 $('roleText').textContent=profile.full_name+' · '+roleName(profile.role);
 $('identity').textContent=roleName(profile.role);
 document.querySelectorAll('.leaders').forEach(e=>e.classList.toggle('hidden',!isManager()));
 document.querySelectorAll('.admins').forEach(e=>e.classList.toggle('hidden',!isAdmin()));
 document.querySelectorAll('.downloaders').forEach(e=>e.classList.toggle('hidden',!canExport()));
 document.querySelector('[data-tab="warranties"]').classList.toggle('hidden',!['admin','supervisor'].includes(profile.role));
 $('salesPanel').classList.toggle('hidden',!['admin','ejecutivo'].includes(profile.role));
 $('masterImportPanel').classList.toggle('hidden',!['admin','ejecutivo'].includes(profile.role));
 $('masterMonth').value=month();$('masterCutoff').value=isoDay();
 $('planDate').value=isoDay();$('salesMonth').value=month();$('monthlyMonth').value=month();view('home');
 await refresh();
 clearInterval(poll);poll=setInterval(()=>{if(me)refresh(true)},30000);
 if(channel)await sb.removeChannel(channel);
 channel=sb.channel('cc-watch-'+me.id).on('postgres_changes',{event:'*',schema:'public',table:'cc_visits'},()=>refresh(true)).on('postgres_changes',{event:'*',schema:'public',table:'cc_assignments'},()=>refresh(true)).subscribe();
}
async function refresh(quiet=false){
 if(!sb||!profile)return;
 try {
 const names=['cc_profiles','cc_branches','cc_sales','cc_assignments','cc_visits','cc_breaks','cc_reports','cc_supervisor_closings','cc_warranties','cc_models','cc_user_imports'];
 const results=await Promise.all(names.map(t=>sb.from(t).select('*').limit(1500)));
 for(let i=0;i<results.length;i++){if(results[i].error)throw results[i].error;data[['profiles','branches','sales','assignments','visits','breaks','reports','closings','warranties','models','user_imports'][i]]=results[i].data||[]}
 $('connection').textContent='En línea · '+new Date().toLocaleTimeString('es-MX',{hour:'2-digit',minute:'2-digit'});
 $('connection').style.background='#e9f8f0';
 render();
 }catch(e){$('connection').textContent='Sin sincronizar';$('connection').style.background='#fff1d8';if(!quiet)error(e)}
}
function render(){
 if(!profile)return;
 $('agendaContent').innerHTML=renderAgenda();
 $('homeContent').innerHTML=renderHome();
 $('historyContent').innerHTML=renderHistory();
 if(isManager()){$('manageContent').innerHTML=renderManage();fillOptions()}
 if(isAdmin()){renderUsers()}
 if(isManager())renderWarranties();
 if(isManager())renderMasterDirectory();
}
function supervisorPortfolio(){
 const mine=data.branches.filter(b=>b.active&&(b.supervisor_id===me.id||(!b.supervisor_id&&b.supervisor_name&&b.supervisor_name.toLowerCase().includes(profile.full_name.split(' ')[0].toLowerCase())))), current=month();
 const owned=new Set(mine.map(b=>b.code));
 const visited=new Set(data.visits.filter(v=>v.user_id===me.id&&owned.has(v.branch_code)&&v.in_at?.slice(0,7)===current).map(v=>v.branch_code));
 const rows=mine.map(b=>({b,sale:data.sales.find(x=>x.branch_code===b.code&&x.period?.slice(0,7)===current),local:/GDL|Zapopan|Guadalajara|Tlaquepaque|Tonalá|Tlajomulco/i.test([b.city,b.region].join(' ')),done:visited.has(b.code)}));
 const target=rows.reduce((n,r)=>n+Number(r.sale?.target_pieces||0),0),actual=rows.reduce((n,r)=>n+Number(r.sale?.actual_pieces||0),0);
 const daily=data.assignments.filter(a=>a.user_id===me.id&&a.day===isoDay()&&a.status!=='cancelled').length;
 return '<div class="panel"><h2>Mi cobertura mensual · '+esc(current)+'</h2><div class="grid">'+
 '<div class="box"><strong>'+rows.filter(r=>r.done).length+' / '+rows.length+'</strong><p class="muted">Visitadas / asignadas</p></div>'+
 '<div class="box"><strong>'+rows.filter(r=>r.local).length+' locales · '+rows.filter(r=>!r.local).length+' foráneas</strong><p class="muted">Cartera</p></div>'+
 '<div class="box"><strong>'+daily+' / 10</strong><p class="muted">Agenda de hoy (indicador)</p></div>'+
 '<div class="box"><strong>'+actual+' / '+target+'</strong><p class="muted">Sell out / meta (piezas)</p></div>'+ '<div class="box"><strong>'+rows.reduce((n,r)=>n+Number(r.sale?.actual_amount||0),0).toLocaleString('es-MX',{style:'currency',currency:'MXN'})+' / '+rows.reduce((n,r)=>n+Number(r.sale?.target_amount||0),0).toLocaleString('es-MX',{style:'currency',currency:'MXN'})+'</strong><p class="muted">Avance / objetivo ($), cuando existen datos</p></div></div>'+
 '<p class="muted"><small>Las visitas de apoyo no cuentan como cobertura propia. Las cifras comerciales se muestran solo si existen en Supabase. La clasificación local/foránea es provisional hasta importar el directorio maestro; el límite de agenda todavía no se aplica aquí.</small></p>'+
 (rows.length?'<div class="tablewrap"><table><thead><tr><th>Sucursal</th><th>Zona</th><th>Mes</th><th>Avance piezas</th><th>Meta piezas</th></tr></thead><tbody>'+rows.map(r=>'<tr><td>'+branchName(r.b.code)+'</td><td>'+(r.local?'Local GDL':'Foránea')+'</td><td>'+(r.done?'Visitada':'Pendiente')+'</td><td>'+(r.sale?.actual_pieces??'Sin carga')+'</td><td>'+(r.sale?.target_pieces??'Sin carga')+'</td></tr>').join('')+'</tbody></table></div>':'<p class="muted">No hay tiendas asignadas a tu usuario en Supabase.</p>')+'</div>';
}
function renderHome(){
 const today=isoDay(), myA=data.assignments.filter(a=>a.user_id===me.id&&a.day===today&&a.status==='scheduled');
 const myV=data.visits.filter(v=>v.user_id===me.id).sort(byDate);
 const act=myV.find(v=>v.status==='active');
 const awaiting=myV.filter(v=>v.status==='awaiting_report');
 let header='<div class="panel"><div class="row between"><div><h2>Mi jornada · '+esc(today)+'</h2><p class="muted">Selecciona tu sucursal asignada y registra tu visita.</p></div>'+badge(roleName(profile.role))+'</div></div>';
 if(['direccion','gerencia','ejecutivo','admin'].includes(profile.role)){
  const live=data.visits.filter(v=>v.status==='active'), done=data.visits.filter(v=>v.status==='complete'), inc=data.assignments.filter(v=>v.status==='scheduled');
  header='<div class="grid"><div class="panel"><h3>Visitas activas</h3><h1>'+live.length+'</h1></div><div class="panel"><h3>Visitas completadas</h3><h1>'+done.length+'</h1></div><div class="panel"><h3>Programaciones</h3><h1>'+inc.length+'</h1></div></div>'+
    '<div class="panel"><h2>Monitoreo general</h2>'+tableVisits(data.visits.slice().sort(byDate).slice(0,30))+'<p class="muted"><small>Actualización automática cada 30 segundos y avisos de cambios en vivo.</small></p></div>';
  return header;
 }
 if(profile.role==='supervisor'){
  const monitored=data.visits.filter(v=>person(v.user_id)?.supervisor_id===me.id);
  header+=supervisorPortfolio();
  header+='<div class="panel"><h2>Promotores de mi equipo</h2>'+tableVisits(monitored.sort(byDate).slice(0,25))+'</div>';
 }
 if(profile.role==='promotor'){
  const b=data.branches.find(x=>x.code===myA[0]?.branch_code);
  const sales=data.sales.find(x=>x.branch_code===b?.code&&x.period?.slice(0,7)===month());
  header+='<div class="panel"><h2>Mi tienda</h2><p>'+ (b?branchName(b.code):'Sin sucursal programada')+'</p><p class="muted">Meta: '+(sales?.target_pieces??'—')+' piezas · Avance: '+(sales?.actual_pieces??'—')+' piezas</p></div>';
 }
 header+='<div class="panel"><h2>Control de asistencia</h2>';
 if(act){
  const total=duration(act.in_at,null), breaks=data.breaks.filter(b=>b.visit_id===act.id), paused=breaks.reduce((n,b)=>n+duration(b.start_at,b.end_at),0);
  header+='<p>'+branchName(act.branch_code)+'</p><div class="timer"><small>Tiempo registrado, descontando pausas</small><br><strong id="runningTimer">'+hm(Math.max(0,total-paused))+'</strong></div><div class="actions"><button class="bad" data-capture="out" data-id="'+esc(act.assignment_id)+'">Registrar salida con selfie</button><button class="light" data-break="'+esc(act.id)+'">'+(breaks.some(b=>!b.end_at)?'Terminar comida':'Iniciar comida')+'</button></div>';
 }else if(myA.length){
  for(const a of myA){
   const existing=data.visits.find(v=>v.assignment_id===a.id);
   header+='<div class="box"><div class="row between"><strong>'+branchName(a.branch_code)+'</strong>'+badge(existing?existing.status:'Programada')+'</div>';
   if(!existing)header+='<button class="good" data-capture="in" data-id="'+esc(a.id)+'" style="margin-top:10px">Registrar entrada con selfie</button>';
   else if(existing.status==='awaiting_report')header+='<button class="primary" data-report="'+esc(existing.id)+'">Completar reporte de cierre</button>';
   header+='</div>';
  }
 }else header+='<p class="muted">No tienes sucursales programadas para hoy. Contacta a tu supervisor.</p>';
 header+='</div>';
 if(awaiting.length)header+='<div class="panel"><h2>Reportes pendientes</h2>'+awaiting.map(v=>'<div class="box">'+branchName(v.branch_code)+' <button class="primary" data-report="'+esc(v.id)+'">Completar cierre</button></div>').join('')+'</div>';
 if(profile.role==='supervisor'){
   const c=data.closings.find(v=>v.user_id===me.id&&v.day===today);
   header+='<div class="panel"><h2>Cierre general del supervisor</h2><form id="superCloseForm"><textarea class="field" id="superComment" maxlength="1000" placeholder="Resumen del día, máximo 1000 caracteres" required>'+esc(c?.comment||'')+'</textarea><button class="primary">Guardar cierre diario</button></form></div>';
 }
 return header;
}
function tableVisits(vs){
 if(!vs.length)return '<p class="muted">Todavía no hay registros.</p>';
 return '<div class="tablewrap"><table><thead><tr><th>Colaborador</th><th>Tienda</th><th>Entrada</th><th>Salida</th><th>Estancia</th><th>Estado</th><th>Foto</th></tr></thead><tbody>'+vs.map(v=>'<tr><td>'+textId(v.user_id)+'</td><td>'+branchName(v.branch_code)+'</td><td>'+fmt(v.in_at)+'</td><td>'+fmt(v.out_at)+'</td><td>'+(v.status==='admin_closed'&&!v.out_at?'—':hm(duration(v.in_at,v.out_at)))+'</td><td>'+badge(v.status)+'</td><td><button class="light" data-proof="'+esc(v.in_photo)+'">Entrada</button> '+(v.out_photo?'<button class="light" data-proof="'+esc(v.out_photo)+'">Salida</button>':'')+'</td></tr>').join('')+'</tbody></table></div>';
}
function renderAgenda(){
 let list=data.assignments.filter(a=>a.user_id===me.id).sort((a,b)=>b.day.localeCompare(a.day));
 return list.length?list.map(a=>'<div class="box"><div class="row between"><div><strong>'+branchName(a.branch_code)+'</strong><p class="muted">'+esc(a.day)+' · '+esc(a.type)+'</p></div>'+badge(a.status)+'</div></div>').join(''):'<p class="muted">No hay visitas asignadas.</p>';
}
function renderHistory(){return tableVisits(data.visits.slice().sort(byDate))}
function renderManage(){
 const a=data.assignments.filter(x=>isLeader()||x.user_id===me.id||person(x.user_id)?.supervisor_id===me.id).sort((a,b)=>b.day.localeCompare(a.day)).slice(0,100);
 return a.length?a.map(x=>{
 const v=data.visits.find(v=>v.assignment_id===x.id);
 const canChange=isManager()&&(profile.role!=='supervisor'||x.user_id!==me.id)&&x.status==='scheduled'&&!v;
 const canClose=isManager()&&(profile.role!=='supervisor'||x.user_id!==me.id)&&x.status==='scheduled';
 return '<div class="box"><div class="row between"><div><strong>'+textId(x.user_id)+'</strong><p class="muted">'+esc(x.day)+' · '+branchName(x.branch_code)+'</p></div>'+badge(v?.status||x.status)+'</div>'+
 (canChange?'<button class="light" data-cancel="'+esc(x.id)+'">Cancelar / Reprogramar</button> ':'')+
 (canClose?'<button class="warn" data-authorize="'+esc(x.id)+'">Cierre autorizado</button>':'')+'</div>';
 }).join(''):'<p class="muted">Aún no hay actividades.</p>';
}
function fillOptions(){
 const users=data.profiles.filter(p=>p.active&&(isLeader()||p.id===me.id||p.supervisor_id===me.id)&&['promotor','supervisor'].includes(p.role));
 const branches=data.branches.filter(b=>b.active);
 $('planUser').innerHTML=options(users,'id',x=>x.full_name+' ('+x.user_code+')');
 $('planBranch').innerHTML=options(branches,'code',x=>'#'+x.code+' '+x.name);
 $('monthlyUser').innerHTML=options(users.filter(p=>p.role==='promotor'),'id',x=>x.full_name+' ('+x.user_code+')');
 $('monthlyBranch').innerHTML=options(branches,'code',x=>'#'+x.code+' '+x.name);
 $('salesBranch').innerHTML=options(branches,'code',x=>'#'+x.code+' '+x.name);
}
function renderWarranties(){
 const branches=data.branches.filter(b=>b.active);
 $('warrantyBranch').innerHTML=options(branches,'code',x=>'#'+x.code+' '+x.name);
 $('warrantyList').innerHTML=data.warranties.length?data.warranties.slice().sort((a,b)=>b.created_at.localeCompare(a.created_at)).map(w=>'<div class="box"><strong>'+esc(w.folio)+'</strong><p>'+branchName(w.branch_code)+' · '+esc(w.inspection_day)+' · '+esc(w.verdict)+'</p><small>'+esc(w.notes)+'</small></div>').join(''):'<p class="muted">Sin inspecciones registradas.</p>';
}

function renderMasterDirectory(){
 const root=$('masterDirectory');if(!root)return;
 const rows=data.branches.slice().sort((a,b)=>Number(a.code)-Number(b.code));
 root.innerHTML='<p class="muted">'+rows.length+' puntos comerciales · '+rows.filter(b=>b.supervisor_name).length+' con responsable identificado · '+rows.filter(b=>b.channel!=='tienda').length+' especiales</p>'+
 '<div style="max-height:360px;overflow:auto"><table style="width:100%;font-size:13px"><thead><tr><th>Tienda</th><th>Supervisor</th><th>Meta / avance</th></tr></thead><tbody>'+
 rows.map(b=>{const sales=data.sales.filter(x=>x.branch_code===b.code).sort((a,b)=>b.period.localeCompare(a.period))[0];return '<tr><td>#'+esc(b.code)+' '+esc(b.name)+'</td><td>'+esc(b.supervisor_name||'Sin asignación')+(b.channel!=='tienda'?' · '+esc(b.channel):'')+'</td><td>'+esc(sales?String(sales.actual_pieces)+' / '+String(sales.target_pieces):'Sin datos')+'</td></tr>'}).join('')+'</tbody></table></div>';
}
function masterHeader(s){return String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[^A-Z0-9]/g,'')}
function masterNum(v){if(v===null||v===undefined||v==='')return null;const n=Number(String(v).replace(/[$,\s]/g,''));return Number.isFinite(n)&&n>=0?n:null}
function masterFind(row,keys){for(const k of keys){const val=row[k];if(val!==undefined&&val!==null&&String(val).trim()!=='')return val}return null}
async function previewMasterExcel(){
 if(!['admin','ejecutivo'].includes(profile.role))throw Error('Sin autorización');
 const file=$('masterFile').files?.[0];if(!file)throw Error('Selecciona un archivo Excel');
 if(!window.XLSX)throw Error('Lector Excel no disponible');
 const wb=window.XLSX.read(await file.arrayBuffer(),{type:'array',cellDates:false});
 const lookup=Object.fromEntries(wb.SheetNames.map(n=>[masterHeader(n),n]));
 for(const n of ['DIRECTORIOTIENDAS','USER','OBJETIVOS','AVANCEMES'])if(!lookup[n])throw Error('Falta la pestaña '+n);
 const get=n=>window.XLSX.utils.sheet_to_json(wb.Sheets[lookup[n]],{header:1,defval:null,raw:true});
 const dir=get('DIRECTORIOTIENDAS').slice(2),us=get('USER').slice(3),obj=get('OBJETIVOS').slice(5),adv=get('AVANCEMES').slice(6);
 const grouped=new Map(),problems=[];
 const code=v=>v===null||v===undefined||String(v).trim()===''?null:String(v).trim().replace(/\.0$/,'');
 const put=(c,values)=>{if(!c||!/^\d+$/.test(c))return;grouped.set(c,{...(grouped.get(c)||{code:c}),...values})};
 const known=new Set(data.branches.map(b=>String(b.code)));
 for(const r of dir){
  const c=code(r[2]);if(!c)continue;
  const supervisor=String(r[6]||'').trim(),supcode=String(r[7]||'').trim();
  put(c,{name:String(r[3]||'').trim(),coverage:String(r[5]||'').trim(),
   supervisor_name:supervisor&&!/^sin cobertura|sin asignar$/i.test(supervisor)?supervisor:null,
   supervisor_user_code:/^SUPER[12]\./i.test(supcode)?supcode:null,
   status_source:String(r[1]||'').trim(),channel:'tienda'});
 }
 for(const r of obj){
  const c=code(r[0]);if(!c)continue;
  const target=masterNum(r[2]),amount=masterNum(r[3]);
  const special=!known.has(c)&&!grouped.has(c);
  put(c,{name:String(r[1]||'').trim(),...(target!==null?{target_pieces:Math.round(target)}:{}),
   ...(amount!==null&&amount<=1000000?{target_amount:amount}:{}),...(special?{channel:'especial',active:false,supervisor_name:null,supervisor_user_code:null}:{})});
  if(amount!==null&&amount>1000000)problems.push('Importe atípico omitido en tienda '+c+': $'+amount.toLocaleString('es-MX'));
 }
 for(const r of adv){
  const c=code(r[1]);if(!c)continue;
  const actual=masterNum(r[4]),goal=masterNum(r[3]);
  if(actual!==null)put(c,{actual_pieces:Math.round(actual)});
  if(goal!==null)put(c,{target_pieces:Math.round(goal)});
 }
 const roleOf=(user,source)=>{
  const r=masterHeader(source),u=user.toUpperCase();
  if(r==='ADMINISTRADOR')return 'admin';
  if(r==='SUPERVISOR')return 'supervisor';
  if(r==='PROMOTOR')return 'promotor';
  if(r==='DIRECCIONEJECUTIVO'){
   if(u.startsWith('GERENTE'))return 'gerencia';
   if(u.startsWith('DIREC'))return 'direccion';
   return 'ejecutivo';
  }
  return null;
 };
 masterUsersDraft=[];
 for(const r of us){
  const user=String(r[1]||'').trim().toUpperCase(),full_name=String(r[5]||'').trim(),role=roleOf(user,r[3]);
  if(!user)continue;
  if(!role||!full_name){problems.push('USER inválido: '+user);continue}
  masterUsersDraft.push({user_code:user,full_name,role,credential_code:String(r[4]||''),source_role:String(r[3]||'')});
 }
 masterDraft=[...grouped.values()];
 if(!masterDraft.length)throw Error('No se reconocieron tiendas');
 const special=masterDraft.filter(r=>r.channel==='especial').length;
 $('masterPreview').textContent='Archivo validado: '+masterDraft.length+' puntos ('+special+' especiales sin supervisor), '+masterUsersDraft.length+' usuarios sin contraseñas. '+(problems.length?'Alertas: '+problems.slice(0,5).join('; '):'');
 $('masterApplyBtn').disabled=false;
}

function renderUsers(){
 $('newUserSupervisor').innerHTML='<option value="">Ninguno</option>'+sopts(data.profiles.filter(p=>p.role==='supervisor'),p=>'<option value="'+esc(p.id)+'">'+esc(p.full_name)+'</option>');
 const pending=data.user_imports.filter(p=>!p.activated);
 $('usersList').innerHTML='<h3>Personal importado desde Excel (sin contraseñas)</h3><p class="muted">'+data.user_imports.length+' usuarios en padrón · '+pending.length+' pendientes de alta/activación. Las contraseñas se asignan individualmente.</p>'+
 data.user_imports.map(p=>'<div class="box"><strong>'+esc(p.full_name)+'</strong><p class="muted">'+esc(p.user_code)+' · '+esc(roleName(p.role))+' · '+(p.activated?'Cuenta existente':'Pendiente de credenciales')+'</p>'+(p.activated?'':'<button class="light" data-prefilluser="'+esc(p.user_code)+'">Preparar alta manual</button>')+'</div>').join('')+
 '<h3 style="margin-top:24px">Personal registrado</h3>'+data.profiles.map(p=>'<div class="box"><div class="row between"><div><strong>'+esc(p.full_name)+'</strong><p class="muted">'+esc(p.user_code)+' · '+roleName(p.role)+' · '+(p.active?'Activo':'Bloqueado')+'</p></div><div class="row"><button class="light" data-reset="'+esc(p.id)+'">Nueva contraseña</button><button class="'+(p.active?'warn':'good')+'" data-toggleuser="'+esc(p.id)+'">'+(p.active?'Bloquear':'Activar')+'</button></div></div></div>').join('');
}
function reportModal(visitId){
 const v=data.visits.find(x=>x.id===visitId);if(!v||v.user_id!==me.id||v.status!=='awaiting_report')return;
 $('modalRoot').innerHTML='<div class="modal"><div class="modalbox"><div class="row between"><h2>Cierre · '+branchName(v.branch_code)+'</h2><button class="light" data-closemodal>✕</button></div>'+
 '<form id="reportForm"><input type="hidden" id="reportVisit" value="'+esc(visitId)+'"><label>Afluencia<select class="field" id="afluencia" required><option>Nula</option><option>Baja</option><option>Media</option><option>Alta</option></select></label><label>Ingresos de clientes (0 a 9999)<input class="field" type="number" min="0" max="9999" id="ingresos" value="0" required></label>'+
 [['venta_america','Venta Colchones América'],['venta_competencia','Ventas competencia'],['presupuesto_america','1 presupuesto Colchones América'],['presupuesto_competencia','1 presupuesto competencia']].map(x=>'<label>'+x[1]+'<textarea class="field" id="'+x[0]+'" maxlength="140" placeholder="Máximo 140 caracteres"></textarea></label>').join('')+
 '<button class="primary" style="width:100%">Guardar cierre comercial</button></form></div></div>';
}
async function startCamera(kind,assignId){
 const a=data.assignments.find(x=>x.id===assignId);
 if(!a||a.user_id!==me.id)return mm('Esta visita no te pertenece',true);
 if(!navigator.mediaDevices?.getUserMedia||!navigator.geolocation)return mm('Se requiere HTTPS, cámara y permiso GPS para asistencia real',true);
 photoAction={kind,assignId};photoBlob=null;geolocation=null;
 $('modalRoot').innerHTML='<div class="modal"><div class="modalbox"><div class="row between"><h2>'+(kind==='in'?'Registrar entrada':'Registrar salida')+'</h2><button class="light" data-closemodal>✕</button></div><p>'+branchName(a.branch_code)+'</p><video autoplay muted playsinline id="camVideo"></video><p id="geoMessage" class="muted">Solicitando GPS de alta precisión...</p><div class="actions"><button class="primary" id="takePhoto">Tomar selfie</button><button class="good" id="sendPhoto" disabled>Confirmar y registrar</button></div><p class="muted"><small>La imagen se guardará en un depósito privado de Supabase. Fecha y hora oficial las registra el servidor.</small></p></div></div>';
 try{stream=await navigator.mediaDevices.getUserMedia({video:{facingMode:'user'},audio:false});$('camVideo').srcObject=stream;await $('camVideo').play()}
 catch(e){closeModal();return error(e)}
 navigator.geolocation.getCurrentPosition(p=>{geolocation={lat:p.coords.latitude,lng:p.coords.longitude,accuracy:p.coords.accuracy};const msg=$('geoMessage');if(msg)msg.textContent='GPS: '+geolocation.lat.toFixed(5)+', '+geolocation.lng.toFixed(5)+' · ±'+Math.round(geolocation.accuracy)+'m';toggleCapture()},
 e=>{let msg=$('geoMessage');if(msg)msg.textContent='No se pudo obtener GPS: '+e.message},
 {enableHighAccuracy:true,maximumAge:0,timeout:15000});
}
function toggleCapture(){if($('sendPhoto'))$('sendPhoto').disabled=!(photoBlob&&geolocation&&geolocation.accuracy<=300)}
function takeSelfie(){
 const v=$('camVideo');if(!v?.videoWidth)return mm('La cámara todavía no está lista',true);
 const c=document.createElement('canvas');c.width=640;c.height=Math.round(v.videoHeight*640/v.videoWidth);
 const ctx=c.getContext('2d');ctx.drawImage(v,0,0,c.width,c.height);
 const label='ColchoCheck · '+new Date().toLocaleString('es-MX')+' · '+(geolocation?geolocation.lat.toFixed(5)+', '+geolocation.lng.toFixed(5):'GPS pendiente');
 ctx.fillStyle='rgba(0,0,0,.72)';ctx.fillRect(0,c.height-46,c.width,46);ctx.fillStyle='white';ctx.font='14px sans-serif';ctx.fillText(label,9,c.height-17,c.width-18);
 c.toBlob(b=>{photoBlob=b;lastPhotoAt=Date.now();if(v){v.poster=URL.createObjectURL(b);v.pause();v.style.display='none';const img=document.createElement('img');img.src=v.poster;img.style.cssText='width:100%;max-height:320px;object-fit:contain;border-radius:12px';v.after(img)}toggleCapture();mm('Fotografía lista')},'image/jpeg',0.72);
}
async function submitCamera(){
 if(!photoBlob||!geolocation||!photoAction)return;
 if(geolocation.accuracy>300)return mm('GPS impreciso: intenta nuevamente al aire libre',true);
 let button=$('sendPhoto');button.disabled=true;button.textContent='Guardando...';
 try{
  const path=me.id+'/'+uid()+'.jpg';
  const u=await sb.storage.from('cc-evidence').upload(path,photoBlob,{contentType:'image/jpeg',upsert:false});
  if(u.error)throw u.error;
  if(photoAction.kind==='in')await rpc('cc_checkin',{p_assignment:photoAction.assignId,p_photo:path,p_lat:geolocation.lat,p_lng:geolocation.lng,p_accuracy:geolocation.accuracy});
  else{
   const v=data.visits.find(v=>v.assignment_id===photoAction.assignId&&v.status==='active');
   if(!v)throw Error('No hay visita abierta');
   await rpc('cc_checkout',{p_visit:v.id,p_photo:path,p_lat:geolocation.lat,p_lng:geolocation.lng,p_accuracy:geolocation.accuracy});
  }
  closeModal();mm('Registro confirmado en servidor');await refresh();
 }catch(e){error(e);if(button){button.disabled=false;button.textContent='Reintentar registro'}}
}
async function openProof(path){
 if(!path)return;
 const r=await sb.storage.from('cc-evidence').createSignedUrl(path,60);
 if(r.error)return error(r.error);
 window.open(r.data.signedUrl,'_blank','noopener,noreferrer');
}
async function exportCSV(){
 if(!canExport())return;
 const header=['Colaborador','Sucursal','Entrada','Salida','Minutos','Estado','Lat Entrada','Lng Entrada','Lat Salida','Lng Salida','Afluencia','Clientes','Venta América','Venta Competencia','Presupuesto América','Presupuesto Competencia','Referencia foto entrada','Referencia foto salida'];
 const rows=data.visits.map(v=>{let r=data.reports.find(r=>r.visit_id===v.id);return [person(v.user_id)?.full_name,v.branch_code,v.in_at,v.out_at,duration(v.in_at,v.out_at),v.status,v.in_lat,v.in_lng,v.out_lat,v.out_lng,r?.afluencia,r?.ingresos,r?.venta_america,r?.venta_competencia,r?.presupuesto_america,r?.presupuesto_competencia,v.in_photo,v.out_photo]});
 const csv=[header,...rows].map(row=>row.map(v=>'"'+String(v??'').replace(/"/g,'""')+'"').join(',')).join('\r\n');
 const file=new Blob(['\ufeff',csv],{type:'text/csv;charset=utf-8'}),url=URL.createObjectURL(file),a=document.createElement('a');a.href=url;a.download='ColchoCheck_Visitas_'+isoDay()+'.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
async function accountAction(op,values){
 const {data:{session}}=await sb.auth.getSession();
 if(!session?.access_token)throw Error('Sesión vencida');
 const r=await fetch(config.url+'/functions/v1/cc-admin-users',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+session.access_token,'apikey':config.publishableKey},body:JSON.stringify({op,...values})});
 const j=await r.json().catch(()=>({error:'Respuesta no válida del servidor'}));if(!r.ok)throw Error(j.error||'Error al administrar usuario');
 return j;
}
async function userAction(id,mode){
 let u=person(id);if(!u)return;
 if(mode==='password'){
  let pw=prompt('Nueva contraseña para '+u.user_code+' (mínimo 10 caracteres):');
  if(!pw)return;
  await accountAction('password',{id,password:pw});mm('Contraseña restablecida. Comunícala de forma privada.');
 }else{
  if(!confirm((u.active?'¿Bloquear':'¿Activar')+' a '+u.full_name+'?'))return;
  await accountAction('active',{id,active:!u.active});mm('Estado actualizado');
 }
 await refresh();
}
document.addEventListener('click',async e=>{
 const b=e.target.closest('button');if(!b)return;
 try{
 if(b.dataset.tab){view(b.dataset.tab);return}
 if(b.hasAttribute('data-closemodal')){closeModal();return}
 if(b.dataset.capture){await startCamera(b.dataset.capture,b.dataset.id);return}
 if(b.id==='takePhoto'){takeSelfie();return}
 if(b.id==='sendPhoto'){await submitCamera();return}
 if(b.dataset.report){reportModal(b.dataset.report);return}
 if(b.dataset.proof){await openProof(b.dataset.proof);return}
 if(b.id==='exportBtn'){await exportCSV();return}
 if(b.dataset.break){let v=data.visits.find(v=>v.id===b.dataset.break);let ongoing=data.breaks.some(x=>x.visit_id===v.id&&!x.end_at);await rpc('cc_break',{p_visit:v.id,p_start:!ongoing});await refresh();return}
 if(b.dataset.cancel){let reason=prompt('Motivo de cancelación o reprogramación');if(reason&&reason.length>=4){await rpc('cc_cancel_assignment',{p_id:b.dataset.cancel,p_reason:reason});await refresh()};return}
 if(b.dataset.authorize){let reason=prompt('Motivo obligatorio del cierre autorizado (no cuenta como visita realizada):');if(reason&&reason.length>=5){await rpc('cc_authorized_close',{p_assignment:b.dataset.authorize,p_reason:reason});await refresh()};return}
 if(b.dataset.reset){await userAction(b.dataset.reset,'password');return}
 if(b.dataset.toggleuser){await userAction(b.dataset.toggleuser,'active');return}
 }catch(err){error(err)}
});
document.addEventListener('click',e=>{
 const code=e.target.dataset?.prefilluser;if(!code)return;
 const user=data.user_imports.find(p=>p.user_code===code);if(!user)return;
 $('newUserId').value=user.user_code;$('newUserName').value=user.full_name;$('newUserRole').value=user.role;
 $('newUserPass').value='';$('newUserPass').focus();mm('Datos precargados. Asigna la contraseña manualmente y confirma el alta.');
});
document.addEventListener('click',async e=>{if(e.target.id==='masterPreviewBtn'){try{await previewMasterExcel()}catch(err){masterDraft=null;masterUsersDraft=[];$('masterApplyBtn').disabled=true;error(err)}}});
document.addEventListener('change',e=>{if(e.target.id==='masterFile'||e.target.id==='masterMonth'||e.target.id==='masterCutoff'){masterDraft=null;masterUsersDraft=[];$('masterApplyBtn').disabled=true;$('masterPreview').textContent='Archivo o periodo modificado. Vuelve a validar.'}});
document.addEventListener('submit',async e=>{
 if(!e.target.id)return;
 e.preventDefault();
 try{
 if(e.target.id==='loginForm'){
  const code=$('usercode').value.trim().toLowerCase();if(!/^[a-z0-9._-]{3,40}$/.test(code))throw Error('ID de usuario inválido');
  const r=await sb.auth.signInWithPassword({email:code+'@'+EMAIL_DOMAIN,password:$('password').value});if(r.error)throw r.error;
  $('password').value='';await initUser(r.data.user);return;
 }
 if(e.target.id==='reportForm'){
  await rpc('cc_close_report',{p_visit:$('reportVisit').value,p_afluencia:$('afluencia').value,p_ingresos:Number($('ingresos').value),p_venta_america:$('venta_america').value,p_venta_competencia:$('venta_competencia').value,p_presupuesto_america:$('presupuesto_america').value,p_presupuesto_competencia:$('presupuesto_competencia').value});closeModal();await refresh();mm('Reporte comercial guardado');return;
 }
 if(e.target.id==='superCloseForm'){await rpc('cc_supervisor_close',{p_day:isoDay(),p_comment:$('superComment').value});mm('Cierre de jornada guardado');await refresh();return}
 if(e.target.id==='masterImportForm'){
  if(!masterDraft?.length)throw Error('Primero valida el Excel');
  if(!['admin','ejecutivo'].includes(profile.role))throw Error('Sin autorización');
  if(!confirm('¿Aplicar '+masterDraft.length+' registros al mes '+$('masterMonth').value+'? Esta operación actualizará datos existentes.'))return;
  const result=await rpc('cc_import_master',{p_period:$('masterMonth').value+'-01',p_cutoff:$('masterCutoff').value,p_rows:masterDraft});
  if(profile.role==='admin'&&masterUsersDraft.length)await rpc('cc_import_users',{p_rows:masterUsersDraft});
  masterDraft=null;masterUsersDraft=[];$('masterApplyBtn').disabled=true;
  $('masterPreview').textContent='Actualización realizada: '+result.updated+' tiendas. Tiendas sin coincidencia: '+(result.missing||[]).join(', ');
  await refresh();mm('Excel maestro actualizado en Supabase');return;
 }
 if(e.target.id==='monthlyPlanForm'){
  if(!isManager())throw Error('Perfil no autorizado');
  const user=$('monthlyUser').value,branch=$('monthlyBranch').value,period=$('monthlyMonth').value;
  const days=new Set([...document.querySelectorAll('input[name="monthlyDay"]:checked')].map(x=>Number(x.value)));
  if(!user||!branch||!/^\\d{4}-\\d{2}$/.test(period)||!days.size)throw Error('Selecciona promotor, tienda, mes y al menos un día');
  const target=data.profiles.find(p=>p.id===user);
  if(!target||target.role!=='promotor'||(isSupervisor()&&target.supervisor_id!==me.id))throw Error('Promotor fuera de tu equipo');
  const [year,mon]=period.split('-').map(Number),count=new Date(year,mon,0).getDate(),dates=[];
  for(let day=1;day<=count;day++){const date=new Date(Date.UTC(year,mon-1,day));if(days.has(date.getUTCDay()))dates.push(period+'-'+String(day).padStart(2,'0'))}
  const existing=new Set(data.assignments.filter(a=>a.user_id===user&&a.branch_code===branch&&a.status==='scheduled').map(a=>a.day));
  const pending=dates.filter(d=>!existing.has(d));
  if(!pending.length)throw Error('Todas las fechas seleccionadas ya están programadas');
  if(!confirm('¿Programar '+pending.length+' visitas de '+target.full_name+' en '+branch+'?'))return;
  const button=$('monthlySubmit');button.disabled=true;let ok=0,failed=[];
  try{
   for(const day of pending){try{await rpc('cc_plan',{p_user:user,p_branch:branch,p_day:day});ok++}catch(err){failed.push(day+': '+(err.message||err))}}
   $('monthlyResult').textContent=ok+' visitas creadas; '+failed.length+' sin registrar.'+(failed.length?' Revisa consola para detalles.':'');
   if(failed.length)console.warn('Fechas sin programar',failed);
   await refresh();mm('Rol mensual: '+ok+' visitas registradas'+(failed.length?' (parcial)':''));
  }finally{button.disabled=false}
  return;
 }
 if(e.target.id==='planForm'){await rpc('cc_plan',{p_user:$('planUser').value,p_branch:$('planBranch').value,p_day:$('planDate').value});mm('Visita programada');await refresh();return}
 if(e.target.id==='warrantyForm'){
  if(!['admin','supervisor'].includes(profile.role))throw Error('Solo supervisores y administradores registran garantías');
  const files=Array.from($('warrantyPhotos').files||[]);
  if(files.length!==6||files.some(f=>!f.type.startsWith('image/')||f.size>8*1024*1024))throw Error('Selecciona exactamente seis imágenes de hasta 8 MB cada una');
  const button=$('warrantySubmit');button.disabled=true;const uploaded=[];
  try{
   for(const file of files){
    const path=me.id+'/warranties/'+uid()+'.jpg';
    const result=await sb.storage.from('cc-evidence').upload(path,file,{contentType:file.type,upsert:false});
    if(result.error)throw result.error;uploaded.push(path);
   }
   const record={user_id:me.id,branch_code:$('warrantyBranch').value,folio:$('warrantyFolio').value.trim(),verdict:$('warrantyVerdict').value,notes:$('warrantyNotes').value.trim(),photos:uploaded};
   const result=await sb.from('cc_warranties').insert(record);
   if(result.error)throw result.error;
   e.target.reset();mm('Garantía registrada con seis evidencias');await refresh();
  }finally{button.disabled=false}
  return;
 }
 if(e.target.id==='salesForm'){const p=$('salesMonth').value+'-01',b=$('salesBranch').value;await rpc('cc_update_sales',{p_branch:b,p_period:p,p_target:Number($('salesTarget').value),p_actual:Number($('salesActual').value)});if($('salesTargetAmount').value!==''||$('salesActualAmount').value!=='')await rpc('cc_update_sales_amounts',{p_branch:b,p_period:p,p_target:$('salesTargetAmount').value===''?null:Number($('salesTargetAmount').value),p_actual:$('salesActualAmount').value===''?null:Number($('salesActualAmount').value)});mm('Meta y avance actualizados');await refresh();return}
 if(e.target.id==='branchForm'){
  if(!isAdmin())throw Error('Solo administrador');
  const r=await sb.from('cc_branches').insert({code:$('branchCode').value.trim(),name:$('branchName').value.trim(),city:$('branchCity').value.trim(),timezone:$('branchTz').value});
  if(r.error)throw r.error;e.target.reset();mm('Sucursal creada');await refresh();return;
 }
 if(e.target.id==='createUserForm'){
  if(!isAdmin())throw Error('Solo administrador');
  await accountAction('create',{code:$('newUserId').value.trim().toUpperCase(),name:$('newUserName').value.trim(),role:$('newUserRole').value,supervisorId:$('newUserSupervisor').value||null,password:$('newUserPass').value});
  $('newUserPass').value='';mm('Usuario creado');await refresh();return;
 }
 }catch(err){error(err)}
});
$('logout').addEventListener('click',async()=>{closeModal();await sb.auth.signOut();location.reload()});
document.querySelectorAll('.tabs button').forEach(b=>b.addEventListener('click',()=>view(b.dataset.tab)));
boot().catch(e=>{console.error(e);window.CC_BOOT_ERROR?.(e?.message||'Error al iniciar la aplicación.');});
