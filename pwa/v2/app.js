import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.10';
import { URL, PUBLISHABLE_KEY } from './config.js';
function clientApp(createClient,URL,PUBLISHABLE_KEY){
"use strict";
const api=createClient(URL,PUBLISHABLE_KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
const root=document.getElementById("app"), flash=document.getElementById("flash");
const state={user:null,profile:null,branches:[],visits:[],tab:"inicio",authMode:"login",selected:"",geo:null,photo:null,detail:null,busy:false};
const cache=new Map();
let lastLookup=0;
const esc=x=>String(x??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const date=x=>x?new Date(x).toLocaleString("es-MX",{timeZone:"America/Mexico_City",dateStyle:"medium",timeStyle:"short"}):"";
const roleName=x=>({admin:"Administrador",ejecutivo:"Ejecutivo",supervisor:"Supervisor",promotor:"Promotor",direccion:"Dirección",gerencia:"Gerencia"}[x]||"Usuario");
function note(msg,bad=false){flash.className="notice "+(bad?"error":"success");flash.textContent=msg;window.scrollTo({top:0,behavior:"smooth"});}
function clearNote(){flash.className="";flash.textContent="";}
function errorOf(e){return e?.message||String(e)||"No fue posible completar la acción";}
async function task(fn){if(state.busy)return;state.busy=true;root.querySelectorAll("button").forEach(b=>b.disabled=true);try{await fn();}catch(e){note(errorOf(e),true)}finally{state.busy=false;root.querySelectorAll("button").forEach(b=>b.disabled=false)}}
const geoMap=g=>{
 if(!g||!Number.isFinite(Number(g.lat))||!Number.isFinite(Number(g.lng)))return "";
 const lat=Number(g.lat),lng=Number(g.lng),d=.003;
 const bbox=[lng-d,lat-.002,lng+d,lat+.002].map(n=>n.toFixed(6)).join(",");
 const src="https://www.openstreetmap.org/export/embed.html?bbox="+encodeURIComponent(bbox)+"&layer=mapnik&marker="+encodeURIComponent(lat.toFixed(6)+","+lng.toFixed(6));
 const full="https://www.openstreetmap.org/?mlat="+lat.toFixed(6)+"&mlon="+lng.toFixed(6)+"#map=17/"+lat.toFixed(6)+"/"+lng.toFixed(6);
 return '<iframe class="map" title="Mapa de ubicación GPS" loading="lazy" referrerpolicy="strict-origin-when-cross-origin" src="'+src+'"></iframe><div class="hint">Mapa: © <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">OpenStreetMap</a> · <a target="_blank" rel="noopener noreferrer" href="'+full+'">Abrir mapa completo</a></div>';
};
const geoCard=g=>!g?"":'<div class="location"><span class="badge good">Ubicación capturada</span><p class="eyebrow">Domicilio aproximado</p><div class="address">'+esc(g.address)+'</div><div class="mono">GPS '+Number(g.lat).toFixed(6)+', '+Number(g.lng).toFixed(6)+' · Precisión ±'+Math.round(g.accuracy)+' m</div><p class="hint">La dirección es una estimación del mapa; el GPS y la fotografía son la evidencia principal.</p>'+geoMap(g)+'</div>';
const bName=id=>state.branches.find(x=>x.id===id)?.name||"Sucursal";
const current=()=>state.visits.find(v=>!v.checkout_at&&v.promoter_id===state.user?.id);
function renderAuth(){
 let signup=state.authMode==="signup";
 root.innerHTML='<div class="shell stack"><div><div class="eyebrow">Acceso seguro</div><h1 class="heading">ColchoCheck V2</h1><p class="muted">Nuevo sistema de asistencia y cobertura.</p></div><div class="card stack"><div><h2>'+(signup?"Crear cuenta de prueba":"Iniciar sesión")+'</h2><p class="sub muted">'+(signup?"Acceso inicial solo a la sucursal ficticia de pruebas.":"Ingresa con tu cuenta de este nuevo proyecto. Las cuentas anteriores aún no se migraron.")+'</p></div><form id="authForm" class="stack">'+(signup?'<label>Nombre completo<input name="name" required maxlength="120" autocomplete="name" placeholder="Nombre y apellido"></label>':'')+'<label>Correo electrónico<input type="email" name="email" required autocomplete="email" placeholder="tu@correo.com"></label><label>Contraseña<input type="password" name="password" minlength="8" required autocomplete="'+(signup?"new-password":"current-password")+'" placeholder="Mínimo 8 caracteres"></label><button class="primary full" type="submit">'+(signup?"Crear cuenta":"Entrar")+'</button></form><button class="light full" type="button" data-action="toggle-auth">'+(signup?"Ya tengo cuenta":"Crear cuenta para pruebas")+'</button></div><div class="notice">Las pruebas se realizan en un proyecto Supabase separado. Los nuevos registros no aparecen en la aplicación anterior.</div></div>';
}
function pageTitle(){
 return {inicio:["Mi jornada","Asistencia y cobertura en tiempo real."],visitas:["Registro de visita","Fotografía, GPS y domicilio en cada movimiento."],historial:["Mis visitas","Evidencia registrada en la nueva base de datos."],perfil:["Mi perfil","Datos y permisos de acceso."]}[state.tab]||["ColchoCheck",""];
}
function navigation(){
 const labels=[["inicio","Inicio"],["visitas","Visitas"],["historial","Historial"],["perfil","Perfil"]];
 return '<nav aria-label="Secciones">'+labels.map(([k,v])=>'<button class="'+(state.tab===k?"active":"")+'" type="button" data-tab="'+k+'">'+v+'</button>').join("")+'</nav>';
}
function home(){
 const open=current(),done=state.visits.filter(v=>v.checkout_at),last=state.visits[0];
 return '<div class="grid"><div class="card"><div class="muted sub">Mis visitas</div><div class="stat">'+state.visits.length+'</div><span class="badge">Registros reales V2</span></div><div class="card"><div class="muted sub">Visitas cerradas</div><div class="stat">'+done.length+'</div><span class="badge good">Con salida</span></div><div class="card"><div class="muted sub">Mi cobertura</div><div class="stat">'+state.branches.length+'</div><span class="badge">Sucursales habilitadas</span></div></div><div class="card stack" style="margin-top:14px"><div class="hstack"><h2>'+(open?"Visita activa":"Siguiente paso")+'</h2><span class="badge '+(open?"goldish":"")+'">'+(open?"Entrada registrada":"Listo")+'</span></div><p class="muted">'+(open?"Estás en "+esc(bName(open.branch_id))+". Registra tu salida cuando termines.":"Comienza registrando tu entrada con selfie y ubicación GPS.")+'</p><button type="button" class="gold" data-tab="visitas">'+(open?"Finalizar visita":"Registrar entrada")+'</button></div>'+(last?'<h3 style="margin:24px 0 10px">Último movimiento</h3><div class="card"><b>'+esc(bName(last.branch_id))+'</b><p class="sub muted">'+date(last.checkin_at)+'</p><p class="sub">'+esc(last.checkin_address)+'</p><span class="badge '+(last.checkout_at?"good":"goldish")+'">'+(last.checkout_at?"Cerrada":"En curso")+'</span></div>':"")+'<div class="notice" style="margin-top:16px">La operación comercial todavía está en preparación. Esta etapa permite validar entrada, salida, domicilio y mapa con datos reales de prueba.</div>';
}
function locationAction(){
 return '<button class="light full" type="button" data-action="gps">📍 Obtener domicilio y mostrar mapa</button><p class="privacy">Al pulsar, autorizas consultar el GPS del teléfono y compartir esa ubicación con OpenStreetMap para obtener una dirección aproximada y visualizar el mapa. Puedes cancelar los permisos del navegador.</p>'+geoCard(state.geo);
}
function photoAction(){
 return '<label>Selfie de evidencia<input id="photo" type="file" accept="image/*" capture="user"></label><div class="photo-file sub">'+(state.photo?'✓ Fotografía seleccionada: '+esc(state.photo.name):'Toca el campo anterior para usar la cámara frontal. La foto se guardará con sello de fecha, domicilio y GPS.')+'</div>';
}
function visitForm(){
 const open=current();if(!state.branches.length)return '<div class="card"><h2>No hay sucursales asignadas</h2><p>Solicita a un administrador que te asigne una sucursal para registrar asistencia.</p></div>';
 if(!open){
  return '<div class="card stack"><div class="hstack"><div><div class="eyebrow">Paso 1</div><h2>Registrar entrada</h2></div><span class="badge">Check-in</span></div><label>Sucursal<select id="branch">'+state.branches.map(b=>'<option value="'+esc(b.id)+'" '+(b.id===state.selected?"selected":"")+'>'+esc(b.store_code)+' · '+esc(b.name)+(b.is_demo?" (PRUEBAS)":"")+'</option>').join("")+'</select></label>'+locationAction()+photoAction()+'<button class="primary full" type="button" data-action="checkin" '+(!state.geo||!state.photo?"disabled":"")+'>Registrar entrada y subir evidencia</button><div class="hint">Se requiere GPS con precisión de hasta 300 metros y una fotografía. La hora oficial la registra el servidor.</div></div>';
 }
 return '<div class="card stack"><div class="hstack"><div><div class="eyebrow">Visita activa</div><h2>'+esc(bName(open.branch_id))+'</h2></div><span class="badge goldish">En curso</span></div><p class="muted sub">Entrada registrada: '+date(open.checkin_at)+'</p>'+geoCard({lat:open.checkin_lat,lng:open.checkin_lng,accuracy:open.checkin_accuracy,address:open.checkin_address})+'<div class="line"></div><h3>Paso 2 · Cerrar visita</h3><form id="checkoutForm" class="stack"><div class="fields"><label>Afluencia<select name="affluence" required><option value="nula">Nula</option><option value="baja">Baja</option><option value="media" selected>Media</option><option value="alta">Alta</option></select></label><label>Ingresos de clientes<input name="customers" type="number" min="0" max="9999" value="0" required></label><label>Venta Colchones América<textarea name="america_sales_note" maxlength="140" rows="2" placeholder="Hasta 140 caracteres"></textarea></label><label>Ventas competencia<textarea name="competition_sales_note" maxlength="140" rows="2"></textarea></label><label>Presupuesto Colchones América<textarea name="america_budget_note" maxlength="140" rows="2"></textarea></label><label>Observaciones<textarea name="observations" maxlength="140" rows="2"></textarea></label></div><div class="line"></div><h3>Ubicación de salida</h3>'+locationAction()+photoAction()+'<button class="primary full" type="submit" '+(!state.geo||!state.photo?"disabled":"")+'>Registrar salida y cerrar visita</button></form></div>';
}
function history(){
 if(!state.visits.length)return '<div class="card"><h2>Sin visitas registradas</h2><p class="muted">Aquí aparecerán tus movimientos reales de la versión V2.</p></div>';
 return '<div class="card"><h2>Historial de esta cuenta</h2>'+state.visits.map(v=>{
 const selected=state.detail===v.id;
 return '<div class="visit-row"><div class="hstack"><div><b>'+esc(bName(v.branch_id))+'</b><div class="muted sub">'+date(v.checkin_at)+'</div></div><span class="badge '+(v.checkout_at?"good":"goldish")+'">'+(v.checkout_at?"Cerrada":"En curso")+'</span></div><p class="sub">📍 '+esc(v.checkin_address)+'</p><button class="light mini" type="button" data-detail="'+esc(v.id)+'">'+(selected?"Ocultar ubicación":"Ver domicilio y mapa")+'</button>'+(selected?'<div class="stack" style="margin-top:13px"><b>Entrada</b>'+geoCard({lat:v.checkin_lat,lng:v.checkin_lng,accuracy:v.checkin_accuracy,address:v.checkin_address})+'<button class="light mini" type="button" data-photo="'+esc(v.checkin_photo_path)+'">Ver selfie de entrada</button>'+(v.checkout_at?'<b>Salida · '+date(v.checkout_at)+'</b>'+geoCard({lat:v.checkout_lat,lng:v.checkout_lng,accuracy:v.checkout_accuracy,address:v.checkout_address})+'<button class="light mini" type="button" data-photo="'+esc(v.checkout_photo_path)+'">Ver selfie de salida</button><span class="muted sub">Afluencia: '+esc(v.affluence)+' · Clientes: '+esc(v.customers)+'</span>':"")+'</div>':"")+'</div>';
 }).join("")+'</div>';
}
function profile(){
 return '<div class="card stack"><h2>'+esc(state.profile?.full_name||"Usuario")+'</h2><span class="badge">'+esc(roleName(state.profile?.role))+'</span><div class="line"></div><div class="sub muted">Correo</div><b>'+esc(state.user?.email)+'</b><div class="sub muted">Proyecto</div><b>ColchoCheck V2 · Independiente</b><div class="sub muted">Alcance actual</div><p>Check-in, check-out, GPS, domicilio aproximado, mapa y fotografías privadas. La configuración avanzada de equipos y objetivos llegará en las siguientes etapas.</p><button class="light full" type="button" data-action="logout">Cerrar sesión</button></div>';
}
function render(){
 if(!state.user)return renderAuth();
 const [title,subtitle]=pageTitle();
 root.innerHTML='<div class="top"><div><div class="eyebrow">'+esc(roleName(state.profile?.role))+'</div><h1 class="heading">'+title+'</h1><p>'+subtitle+'</p></div><button class="light mini" type="button" data-action="reload">Actualizar</button></div>'+navigation()+(state.tab==="inicio"?home():state.tab==="visitas"?visitForm():state.tab==="historial"?history():profile());
}
async function refresh(){
 const u=state.user;if(!u)return;
 const [pr,br,vi]=await Promise.all([
  api.from("ccv2_profiles").select("id,full_name,role,active").eq("id",u.id).maybeSingle(),
  api.from("ccv2_branches").select("id,store_code,name,city,address,is_demo").order("name"),
  api.from("ccv2_visits").select("*").eq("promoter_id",u.id).order("checkin_at",{ascending:false}).limit(50)
 ]);
 for(const result of [pr,br,vi])if(result.error)throw result.error;
 state.profile=pr.data;state.branches=br.data||[];state.visits=vi.data||[];
 if(!state.profile)throw Error("No se encontró tu perfil. Cierra sesión y contacta al administrador.");
 if(!state.profile.active)throw Error("Tu cuenta está desactivada. Contacta al administrador.");
 if(!state.branches.some(x=>x.id===state.selected)){state.selected=state.branches.find(x=>x.is_demo)?.id||state.branches[0]?.id||""}
 render();
}
async function login(form){
 const email=form.elements.email.value.trim(),password=form.elements.password.value;
 if(state.authMode==="signup"){
  const full_name=form.elements.name.value.trim();if(!full_name)throw Error("Ingresa tu nombre.");
  const {data,error}=await api.auth.signUp({email,password,options:{data:{full_name}}});
  if(error)throw error;
  if(data.session&&data.user){state.user=data.user;await refresh();note("Cuenta creada. Ya puedes probar la sucursal de demostración.");}
  else{state.authMode="login";render();note("Solicitud recibida. Revisa tu correo y confirma tu cuenta antes de iniciar sesión.")}
  return;
 }
 const {data,error}=await api.auth.signInWithPassword({email,password});
 if(error)throw error;state.user=data.user;state.geo=null;state.photo=null;await refresh();clearNote();
}
async function logout(){
 const {error}=await api.auth.signOut();if(error)throw error;state.user=null;state.profile=null;state.visits=[];state.branches=[];state.geo=null;state.photo=null;state.tab="inicio";clearNote();render();
}
async function addressFor(lat,lng){
 const key=lat.toFixed(4)+","+lng.toFixed(4);if(cache.has(key))return cache.get(key);
 const delta=Date.now()-lastLookup;if(delta<1500)await new Promise(r=>setTimeout(r,1500-delta));
 lastLookup=Date.now();
 const controller=new AbortController();const t=setTimeout(()=>controller.abort(),8500);
 try{
  const url="https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=18&addressdetails=1&accept-language=es&lat="+encodeURIComponent(lat.toFixed(7))+"&lon="+encodeURIComponent(lng.toFixed(7));
  const resp=await fetch(url,{signal:controller.signal,headers:{"Accept":"application/json"}});
  if(!resp.ok)throw Error("Servicio de domicilio temporalmente indisponible");
  const data=await resp.json();
  const address=data.display_name?.trim()||"Domicilio aproximado no disponible";
  cache.set(key,address);return address;
 }catch(_){return "Domicilio aproximado no disponible. Revisa el mapa."}finally{clearTimeout(t)}
}
async function getLocation(){
 if(!navigator.geolocation)throw Error("Este navegador no permite usar GPS.");
 note("Solicitando permiso GPS y localizando tu domicilio...");
 const p=await new Promise((resolve,reject)=>navigator.geolocation.getCurrentPosition(resolve,reject,{enableHighAccuracy:true,timeout:25000,maximumAge:0}));
 const accuracy=Number(p.coords.accuracy);
 if(!Number.isFinite(accuracy)||accuracy>300)throw Error("Precisión GPS insuficiente (±"+Math.round(accuracy)+" m). Activa ubicación precisa y vuelve a intentarlo.");
 const lat=p.coords.latitude,lng=p.coords.longitude;
 if(!Number.isFinite(lat)||!Number.isFinite(lng))throw Error("Coordenadas GPS inválidas.");
 state.geo={lat,lng,accuracy,address:"Consultando domicilio aproximado…"};
 render();state.geo.address=await addressFor(lat,lng);
 render();clearNote();
}
async function compressPhoto(file,geo){
 if(!file||!file.type.startsWith("image/"))throw Error("Selecciona una fotografía válida.");
 if(file.size>15*1024*1024)throw Error("La imagen es demasiado grande.");
 const src=window.URL.createObjectURL(file);const img=new Image();
 try{
  await new Promise((resolve,reject)=>{img.onload=resolve;img.onerror=()=>reject(Error("No fue posible abrir la imagen"));img.src=src});
  const scale=Math.min(1,1280/Math.max(img.naturalWidth,img.naturalHeight));const w=Math.max(1,Math.round(img.naturalWidth*scale)),h=Math.max(1,Math.round(img.naturalHeight*scale));
  const canvas=document.createElement("canvas");canvas.width=w;canvas.height=h;const c=canvas.getContext("2d");c.drawImage(img,0,0,w,h);
  const height=Math.max(82,Math.round(h*.14)),font=Math.max(13,Math.round(w*.025));
  c.fillStyle="rgba(12,22,31,.87)";c.fillRect(0,h-height,w,height);c.fillStyle="white";c.font="600 "+font+"px system-ui";
  c.fillText("COLCHOCHECK V2  ·  "+new Date().toLocaleString("es-MX"),12,h-height+font+8,w-22);
  c.font=Math.round(font*.81)+"px system-ui";c.fillText("GPS "+geo.lat.toFixed(5)+", "+geo.lng.toFixed(5)+"  ±"+Math.round(geo.accuracy)+"m",12,h-height+font*2+10,w-22);
  c.fillText("DOMICILIO APROX: "+geo.address,12,h-9,w-22);
  const blob=await new Promise((resolve,reject)=>canvas.toBlob(b=>b?resolve(b):reject(Error("No fue posible preparar la selfie")),"image/jpeg",.79));
  if(blob.size>5*1024*1024)throw Error("La fotografía supera el límite del almacenamiento.");
  return blob;
 }finally{window.URL.revokeObjectURL(src)}
}
async function upload(visitId,side){
 if(!state.geo||!state.photo)throw Error("Necesitas GPS y fotografía antes de continuar.");
 const path=state.user.id+"/"+visitId+"/"+side+".jpg";
 const blob=await compressPhoto(state.photo,state.geo);
 const {error}=await api.storage.from("ccv2-evidence").upload(path,blob,{contentType:"image/jpeg",upsert:false});
 if(error&&!(side==="salida"&&(/already exists|resource already exists|duplicate/i.test(error.message)||String(error.statusCode)==="409")))throw error;
 return path;
}
async function checkin(){
 if(!state.selected)throw Error("Selecciona una sucursal.");
 if(!state.geo||!state.photo)throw Error("Captura tu GPS y selfie.");
 note("Guardando selfie y entrada segura...");
 const id=crypto.randomUUID(),path=await upload(id,"entrada");
 const g=state.geo;
 const {error}=await api.from("ccv2_visits").insert({id,promoter_id:state.user.id,branch_id:state.selected,checkin_lat:g.lat,checkin_lng:g.lng,checkin_accuracy:g.accuracy,checkin_address:g.address,checkin_photo_path:path});
 if(error)throw error;state.geo=null;state.photo=null;state.tab="visitas";await refresh();note("Entrada registrada con fotografía, ubicación y domicilio.");
}
async function checkout(form){
 const v=current();if(!v)throw Error("No tienes una visita activa.");
 if(!state.geo||!state.photo)throw Error("Captura una nueva ubicación y una selfie de salida.");
 const customers=Number(form.elements.customers.value);
 if(!Number.isInteger(customers)||customers<0||customers>9999)throw Error("Número de clientes inválido.");
 note("Guardando selfie y cierre de visita...");
 const path=await upload(v.id,"salida"),g=state.geo;
 const fields=["america_sales_note","competition_sales_note","america_budget_note","observations"],values={};
 fields.forEach(k=>{values[k]=form.elements[k].value.trim().slice(0,140)});
 const {data,error}=await api.from("ccv2_visits").update({
  checkout_at:new Date().toISOString(),checkout_lat:g.lat,checkout_lng:g.lng,checkout_accuracy:g.accuracy,
  checkout_address:g.address,checkout_photo_path:path,affluence:form.elements.affluence.value,customers,...values
 }).eq("id",v.id).is("checkout_at",null).select("id").maybeSingle();
 if(error)throw error;if(!data)throw Error("La visita no se pudo cerrar; actualiza la pantalla para revisar su estado.");
 state.geo=null;state.photo=null;state.tab="historial";await refresh();note("Salida registrada. Visita cerrada correctamente.");
}
root.addEventListener("submit",e=>{
 if(e.target.id!=="authForm"&&e.target.id!=="checkoutForm")return;
 e.preventDefault();const form=e.target;
 task(()=>form.id==="authForm"?login(form):checkout(form));
});
root.addEventListener("change",e=>{
 if(e.target.id==="branch"){state.selected=e.target.value;return}
 if(e.target.id==="photo"){const file=e.target.files?.[0]||null;if(file&&!file.type.startsWith("image/")){note("Selecciona una imagen.",true);return}state.photo=file;render()}
});
root.addEventListener("click",e=>{
 const tab=e.target.closest("[data-tab]");if(tab){state.tab=tab.dataset.tab;state.geo=null;state.photo=null;clearNote();render();return}
 const detail=e.target.closest("[data-detail]");if(detail){state.detail=state.detail===detail.dataset.detail?null:detail.dataset.detail;render();return}
 const photo=e.target.closest("[data-photo]");if(photo){const path=photo.dataset.photo;task(async()=>{
  const {data,error}=await api.storage.from("ccv2-evidence").createSignedUrl(path,90);if(error)throw error;
  flash.className="notice success";flash.innerHTML='Fotografía privada lista: <a target="_blank" rel="noopener noreferrer" href="'+esc(data.signedUrl)+'">abrir evidencia (válida 90 segundos)</a>.';
 });return}
 const action=e.target.closest("[data-action]")?.dataset.action;
 if(action==="toggle-auth"){state.authMode=state.authMode==="login"?"signup":"login";clearNote();render();return}
 if(action==="gps")return task(getLocation);
 if(action==="checkin")return task(checkin);
 if(action==="logout")return task(logout);
 if(action==="reload")return task(async()=>{await refresh();note("Datos actualizados.")});
});
(async()=>{
 try{const {data,error}=await api.auth.getUser();if(error&&!/session missing/i.test(error.message||""))throw error;
  if(data?.user){state.user=data.user;await refresh()}else render();
 }catch(e){state.user=null;renderAuth();note("No pudimos abrir la sesión: "+errorOf(e),true)}
})();
}
clientApp(createClient,URL,PUBLISHABLE_KEY);
