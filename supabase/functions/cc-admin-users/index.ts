// Supabase Edge Function: cc-admin-users
// Deploy with Verify JWT enabled; uses server-only SUPABASE_SERVICE_ROLE_KEY.
// An administrator account and its cc_profiles row must be bootstrapped manually.
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.10";

const url = Deno.env.get("SUPABASE_URL") || "";
const pub = Deno.env.get("SUPABASE_ANON_KEY") || "";
const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const suffix = "@users.colchocheck.example.com";
const roles = new Set(["promotor","supervisor","ejecutivo","gerencia","direccion"]);
const json = (body: unknown, status=200)=>new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"}});
serve(async(req:Request)=>{
  if(req.method!=="POST")return json({error:"Método no permitido"},405);
  const auth=req.headers.get("Authorization")||"";
  if(!auth.startsWith("Bearer ")||!url||!pub||!secret)return json({error:"Autenticación no disponible"},401);
  const jwt=auth.slice(7);
  const client=createClient(url,pub,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
  const {data:{user},error:authErr}=await client.auth.getUser(jwt);
  if(authErr||!user)return json({error:"Sesión inválida"},401);
  const admin=createClient(url,secret,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:actor,error:actorErr}=await admin.from("cc_profiles").select("id,role,active").eq("id",user.id).single();
  if(actorErr||!actor||!actor.active||actor.role!=="admin")return json({error:"Acceso exclusivo de administrador"},403);
  let body:Record<string,unknown>;
  try{body=await req.json()}catch{return json({error:"JSON inválido"},400)}
  try{
    if(body.op==="create"){
      const code=String(body.code||"").trim().toUpperCase();
      const name=String(body.name||"").trim();
      const role=String(body.role||"");
      const password=String(body.password||"");
      if(!/^[A-Z0-9._-]{3,40}$/.test(code))return json({error:"Código inválido"},400);
      if(name.length<3||name.length>160||!roles.has(role))return json({error:"Nombre o perfil inválido"},400);
      if(password.length<10||password.length>128)return json({error:"Contraseña debe tener entre 10 y 128 caracteres"},400);
      let supervisorId=body.supervisorId||null;
      if(supervisorId && role==="promotor"){
        const {data:s}=await admin.from("cc_profiles").select("role,active").eq("id",String(supervisorId)).single();
        if(!s||s.role!=="supervisor"||!s.active)return json({error:"Supervisor no autorizado"},400);
      }else supervisorId=null;
      const {data:authData,error:e}=await admin.auth.admin.createUser({
        email:code.toLowerCase()+suffix,password,email_confirm:true,
        app_metadata:{colchocheck:true}
      });
      if(e)return json({error:e.message},400);
      const id=authData.user.id;
      const {error:pe}=await admin.from("cc_profiles").insert({id,user_code:code,full_name:name,role,supervisor_id:supervisorId,active:true});
      if(pe){await admin.auth.admin.deleteUser(id);return json({error:pe.message},400)}
      await admin.from("cc_audit").insert({actor_id:user.id,action:"USER_CREATED",target:id,reason:code});
      return json({ok:true,id,code});
    }
    if(body.op==="password"||body.op==="active"){
      const id=String(body.id||"");
      if(!/^[0-9a-f-]{36}$/i.test(id))return json({error:"ID inválido"},400);
      const {data:target,error:te}=await admin.from("cc_profiles").select("id,role").eq("id",id).single();
      if(te||!target)return json({error:"Usuario no encontrado"},404);
      if(target.role==="admin")return json({error:"La cuenta administradora está protegida"},403);
      if(body.op==="password"){
        const password=String(body.password||"");
        if(password.length<10||password.length>128)return json({error:"Contraseña debe tener entre 10 y 128 caracteres"},400);
        const {error:pwErr}=await admin.auth.admin.updateUserById(id,{password});
        if(pwErr)return json({error:pwErr.message},400);
        await admin.from("cc_audit").insert({actor_id:user.id,action:"PASSWORD_RESET",target:id,reason:"Restablecida"});
        return json({ok:true});
      }
      const active=body.active===true;
      const {error:upErr}=await admin.from("cc_profiles").update({active}).eq("id",id);
      if(upErr)return json({error:upErr.message},400);
      if(!active)await admin.auth.admin.signOut(id,"global").catch(()=>{});
      await admin.from("cc_audit").insert({actor_id:user.id,action:active?"USER_ENABLED":"USER_BLOCKED",target:id});
      return json({ok:true});
    }
    return json({error:"Operación desconocida"},400);
  }catch(e){return json({error:e instanceof Error?e.message:"Error no esperado"},500)}
});