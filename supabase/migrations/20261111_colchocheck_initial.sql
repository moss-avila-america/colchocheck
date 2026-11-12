-- ColchoCheck App | esquema inicial de beta conectada
-- Ejecutar SOLO en un proyecto Supabase nuevo. No incluye usuarios ni contraseñas.
create extension if not exists pgcrypto;

create table if not exists public.cc_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  user_code text not null unique,
  full_name text not null,
  role text not null check (role in ('admin','direccion','gerencia','ejecutivo','supervisor','promotor')),
  supervisor_id uuid references public.cc_profiles(id),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.cc_branches (
  code text primary key,
  name text not null,
  city text not null default '',
  region text not null default '',
  timezone text not null default 'America/Mexico_City',
  latitude double precision, longitude double precision,
  supervisor_id uuid references public.cc_profiles(id),
  active boolean not null default true
);
create table if not exists public.cc_sales (
  branch_code text not null references public.cc_branches(code),
  period date not null,
  target_pieces integer not null default 0 check (target_pieces >= 0),
  actual_pieces integer not null default 0 check (actual_pieces >= 0),
  updated_by uuid references public.cc_profiles(id),
  updated_at timestamptz not null default now(),
  primary key(branch_code, period)
);
create table if not exists public.cc_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.cc_profiles(id),
  branch_code text not null references public.cc_branches(code),
  day date not null,
  type text not null check(type in ('promotor','supervisor')),
  status text not null default 'scheduled' check(status in ('scheduled','cancelled','admin_closed')),
  note text not null default '',
  created_by uuid references public.cc_profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists cc_assignments_user_date on public.cc_assignments(user_id, day);
create table if not exists public.cc_visits (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null unique references public.cc_assignments(id),
  user_id uuid not null references public.cc_profiles(id),
  branch_code text not null references public.cc_branches(code),
  status text not null default 'active' check(status in ('active','awaiting_report','complete','admin_closed')),
  in_at timestamptz not null default now(),
  out_at timestamptz,
  in_lat double precision, in_lng double precision, in_accuracy double precision,
  out_lat double precision, out_lng double precision, out_accuracy double precision,
  in_photo text not null, out_photo text,
  simulated boolean not null default false,
  closed_by uuid references public.cc_profiles(id),
  closure_note text,
  created_at timestamptz not null default now()
);
create index if not exists cc_visits_user_date on public.cc_visits(user_id, in_at desc);
create unique index if not exists cc_one_active_visit_per_user on public.cc_visits(user_id) where status='active';
create table if not exists public.cc_breaks(
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.cc_visits(id),
  start_at timestamptz not null default now(),
  end_at timestamptz
);
create unique index if not exists cc_one_open_break_per_visit on public.cc_breaks(visit_id) where end_at is null;
create table if not exists public.cc_reports(
  visit_id uuid primary key references public.cc_visits(id) on delete cascade,
  afluencia text not null check(afluencia in ('Nula','Baja','Media','Alta')),
  ingresos integer not null check(ingresos between 0 and 9999),
  venta_america varchar(140) not null default '',
  venta_competencia varchar(140) not null default '',
  presupuesto_america varchar(140) not null default '',
  presupuesto_competencia varchar(140) not null default '',
  created_at timestamptz not null default now()
);
create table if not exists public.cc_supervisor_closings(
  user_id uuid not null references public.cc_profiles(id),
  day date not null,
  comment varchar(1000) not null,
  created_at timestamptz not null default now(),
  primary key(user_id,day)
);
create table if not exists public.cc_audit(
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  actor_id uuid references public.cc_profiles(id),
  action text not null,
  target text,
  reason text
);

create or replace function public.cc_role() returns text
language sql stable security definer set search_path = public
as $$ select role from public.cc_profiles where id=auth.uid() and active=true limit 1 $$;
create or replace function public.cc_can_read_user(target uuid) returns boolean
language sql stable security definer set search_path = public
as $$
  select auth.uid()=target
    or public.cc_role() in ('admin','direccion','gerencia','ejecutivo')
    or (public.cc_role()='supervisor' and exists(
      select 1 from public.cc_profiles p where p.id=target and p.supervisor_id=auth.uid()
    ))
$$;
create or replace function public.cc_can_plan_user(target uuid) returns boolean
language sql stable security definer set search_path = public
as $$
 select public.cc_role() in ('admin','ejecutivo')
    or (public.cc_role()='supervisor' and (target=auth.uid()
       or exists(select 1 from public.cc_profiles p
                 where p.id=target and p.role='promotor' and p.supervisor_id=auth.uid())))
$$;

alter table public.cc_profiles enable row level security;
alter table public.cc_branches enable row level security;
alter table public.cc_sales enable row level security;
alter table public.cc_assignments enable row level security;
alter table public.cc_visits enable row level security;
alter table public.cc_breaks enable row level security;
alter table public.cc_reports enable row level security;
alter table public.cc_supervisor_closings enable row level security;
alter table public.cc_audit enable row level security;

create policy "profiles scope" on public.cc_profiles for select to authenticated using (public.cc_can_read_user(id));
create policy "branches for staff" on public.cc_branches for select to authenticated using (
 public.cc_role() in ('admin','direccion','gerencia','ejecutivo','supervisor')
 or exists(select 1 from public.cc_assignments a where a.branch_code=cc_branches.code and a.user_id=auth.uid())
);
create policy "branches admin write" on public.cc_branches for all to authenticated
  using (public.cc_role()='admin') with check (public.cc_role()='admin');
create policy "sales staff read" on public.cc_sales for select to authenticated using (
 public.cc_role() in ('admin','ejecutivo','direccion','gerencia','supervisor')
 or (public.cc_role()='promotor' and exists(
   select 1 from public.cc_assignments a where a.user_id=auth.uid() and a.branch_code=cc_sales.branch_code
 ))
);
create policy "assignments scope" on public.cc_assignments for select to authenticated using (public.cc_can_read_user(user_id));
create policy "visits scope" on public.cc_visits for select to authenticated using (public.cc_can_read_user(user_id));
create policy "breaks scope" on public.cc_breaks for select to authenticated using (
  exists(select 1 from public.cc_visits v where v.id=visit_id and public.cc_can_read_user(v.user_id)));
create policy "reports scope" on public.cc_reports for select to authenticated using (
  exists(select 1 from public.cc_visits v where v.id=visit_id and public.cc_can_read_user(v.user_id)));
create policy "closing scope" on public.cc_supervisor_closings for select to authenticated using (public.cc_can_read_user(user_id));
create policy "audit leaders read" on public.cc_audit for select to authenticated using (public.cc_role() in ('admin','direccion','gerencia','ejecutivo'));

-- Las modificaciones críticas SOLO pasan por las funciones abajo, nunca por UPDATE directo.
revoke all on public.cc_profiles, public.cc_assignments, public.cc_visits,
  public.cc_breaks, public.cc_reports, public.cc_supervisor_closings,
  public.cc_sales, public.cc_audit from anon;
grant select on public.cc_profiles, public.cc_branches, public.cc_sales,
  public.cc_assignments, public.cc_visits, public.cc_breaks,
  public.cc_reports, public.cc_supervisor_closings, public.cc_audit to authenticated;

create or replace function public.cc_plan(p_user uuid,p_branch text,p_day date)
returns uuid language plpgsql security definer set search_path=public as $$
declare target_role text; n int; assignment_uuid uuid; supervisor_uuid uuid;
begin
 if not public.cc_can_plan_user(p_user) then raise exception 'No tienes permiso para programar este usuario'; end if;
 select role, supervisor_id into target_role,supervisor_uuid from public.cc_profiles where id=p_user and active;
 if target_role not in ('promotor','supervisor') then raise exception 'Perfil no programable'; end if;
 if not exists(select 1 from public.cc_branches where code=p_branch and active) then raise exception 'Sucursal inexistente'; end if;
 if target_role='supervisor' then
  select count(*) into n from public.cc_assignments where user_id=p_user and day=p_day and status='scheduled';
  if n>=10 then raise exception 'Máximo 10 visitas diarias'; end if;
 end if;
 insert into public.cc_assignments(user_id,branch_code,day,type,created_by)
 values(p_user,p_branch,p_day,target_role,auth.uid()) returning id into assignment_uuid;
 insert into public.cc_audit(actor_id,action,target,reason) values(auth.uid(),'ROL_ASIGNADO',assignment_uuid::text,p_branch||' '||p_day);
 return assignment_uuid;
end $$;

create or replace function public.cc_cancel_assignment(p_id uuid,p_reason text)
returns void language plpgsql security definer set search_path=public as $$
declare a public.cc_assignments%rowtype;
begin
 select * into a from public.cc_assignments where id=p_id for update;
 if not found or not public.cc_can_plan_user(a.user_id) then raise exception 'Sin permiso'; end if;
 if exists(select 1 from public.cc_visits where assignment_id=p_id) then raise exception 'Visita iniciada: requiere autorización administrativa'; end if;
 if length(trim(p_reason))<4 then raise exception 'Indica motivo'; end if;
 update public.cc_assignments set status='cancelled',note=left(p_reason,500) where id=p_id;
 insert into public.cc_audit(actor_id,action,target,reason) values(auth.uid(),'ROL_CANCELADO',p_id::text,p_reason);
end $$;

create or replace function public.cc_evidence_ok(p_path text) returns boolean
language sql stable security definer set search_path=public,storage
as $
 select p_path like auth.uid()::text || '/%' and exists(
  select 1 from storage.objects o
  where o.bucket_id='cc-evidence' and o.name=p_path
    and o.created_at > now() - interval '10 minutes'
    and not exists(
      select 1 from public.cc_visits v where v.in_photo=p_path or v.out_photo=p_path
    )
 )
$;

create or replace function public.cc_checkin(p_assignment uuid,p_photo text,p_lat double precision,p_lng double precision,p_accuracy double precision)
returns uuid language plpgsql security definer set search_path=public as $$
declare a public.cc_assignments%rowtype; result_id uuid; tz text;
begin
 select * into a from public.cc_assignments where id=p_assignment and user_id=auth.uid() and status='scheduled';
 if not found or public.cc_role() not in ('promotor','supervisor') then raise exception 'Sin rol de visita autorizado'; end if;
 select timezone into tz from public.cc_branches where code=a.branch_code;
 if a.day != (now() at time zone coalesce(tz,'America/Mexico_City'))::date then raise exception 'Esta visita no corresponde al día actual'; end if;
 if p_lat is null or p_lng is null or p_accuracy is null or p_accuracy > 300 then raise exception 'GPS insuficiente'; end if;
 if not public.cc_evidence_ok(p_photo) then raise exception 'Fotografía no recibida'; end if;
 if exists(select 1 from public.cc_visits where user_id=auth.uid() and status='active') then raise exception 'Cierra tu visita actual'; end if;
 insert into public.cc_visits(assignment_id,user_id,branch_code,in_photo,in_lat,in_lng,in_accuracy)
 values(p_assignment,auth.uid(),a.branch_code,p_photo,p_lat,p_lng,p_accuracy) returning id into result_id;
 insert into public.cc_audit(actor_id,action,target) values(auth.uid(),'CHECK_IN',result_id::text);
 return result_id;
end $$;

create or replace function public.cc_checkout(p_visit uuid,p_photo text,p_lat double precision,p_lng double precision,p_accuracy double precision)
returns void language plpgsql security definer set search_path=public as $$
declare v public.cc_visits%rowtype;
begin
 select * into v from public.cc_visits where id=p_visit and user_id=auth.uid() and status='active' for update;
 if not found then raise exception 'Visita no activa'; end if;
 if p_lat is null or p_lng is null or p_accuracy is null or p_accuracy>300 then raise exception 'GPS insuficiente'; end if;
 if not public.cc_evidence_ok(p_photo) then raise exception 'Fotografía no recibida'; end if;
 update public.cc_breaks set end_at=now() where visit_id=p_visit and end_at is null;
 update public.cc_visits set out_at=now(),out_photo=p_photo,out_lat=p_lat,out_lng=p_lng,
 out_accuracy=p_accuracy,status=case when public.cc_role()='promotor' then 'awaiting_report' else 'complete' end
 where id=p_visit;
 insert into public.cc_audit(actor_id,action,target) values(auth.uid(),'CHECK_OUT',p_visit::text);
end $$;

create or replace function public.cc_break(p_visit uuid,p_start boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from public.cc_visits where id=p_visit and user_id=auth.uid() and status='active') then raise exception 'Visita no activa'; end if;
 if p_start then
   if exists(select 1 from public.cc_breaks where visit_id=p_visit and end_at is null) then raise exception 'Pausa abierta'; end if;
   insert into public.cc_breaks(visit_id) values(p_visit);
 else
   if not exists(select 1 from public.cc_breaks where visit_id=p_visit and end_at is null) then raise exception 'No hay pausa abierta'; end if;
   update public.cc_breaks set end_at=now() where visit_id=p_visit and end_at is null;
 end if;
end $$;

create or replace function public.cc_close_report(
 p_visit uuid,p_afluencia text,p_ingresos integer,
 p_venta_america text,p_venta_competencia text,p_presupuesto_america text,p_presupuesto_competencia text)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from public.cc_visits where id=p_visit and user_id=auth.uid() and status='awaiting_report')
 then raise exception 'Primero registra la salida'; end if;
 if p_afluencia not in ('Nula','Baja','Media','Alta') or p_ingresos not between 0 and 9999 then raise exception 'Valores inválidos'; end if;
 if greatest(length(p_venta_america),length(p_venta_competencia),length(p_presupuesto_america),length(p_presupuesto_competencia))>140 then raise exception 'Límite 140 caracteres'; end if;
 insert into public.cc_reports(visit_id,afluencia,ingresos,venta_america,venta_competencia,presupuesto_america,presupuesto_competencia)
 values(p_visit,p_afluencia,p_ingresos,p_venta_america,p_venta_competencia,p_presupuesto_america,p_presupuesto_competencia);
 update public.cc_visits set status='complete' where id=p_visit;
 insert into public.cc_audit(actor_id,action,target) values(auth.uid(),'REPORTE_CIERRE',p_visit::text);
end $$;

create or replace function public.cc_supervisor_close(p_day date,p_comment text)
returns void language plpgsql security definer set search_path=public as $$
begin
 if public.cc_role()<>'supervisor' or length(p_comment)>1000 or length(trim(p_comment))<1 then raise exception 'Operación no autorizada'; end if;
 insert into public.cc_supervisor_closings(user_id,day,comment) values(auth.uid(),p_day,p_comment)
 on conflict(user_id,day) do update set comment=excluded.comment,created_at=now();
end $$;

create or replace function public.cc_authorized_close(p_assignment uuid,p_reason text)
returns void language plpgsql security definer set search_path=public as $$
declare a public.cc_assignments%rowtype; v public.cc_visits%rowtype;
begin
 select * into a from public.cc_assignments where id=p_assignment for update;
 if not found then raise exception 'Visita desconocida'; end if;
 if public.cc_role() not in ('admin','ejecutivo') and not (public.cc_role()='supervisor' and public.cc_can_plan_user(a.user_id) and a.user_id<>auth.uid()) then raise exception 'Sin autorización'; end if;
 if length(trim(p_reason))<5 then raise exception 'Debes justificar el cierre'; end if;
 select * into v from public.cc_visits where assignment_id=p_assignment;
 if found and v.status<>'active' then raise exception 'Visita ya finalizada'; end if;
 if found then
   update public.cc_visits set status='admin_closed',closed_by=auth.uid(),closure_note=left(p_reason,500) where id=v.id;
 else
   update public.cc_assignments set status='admin_closed',note=left(p_reason,500) where id=p_assignment;
 end if;
 insert into public.cc_audit(actor_id,action,target,reason) values(auth.uid(),'CIERRE_AUTORIZADO',p_assignment::text,p_reason);
end $$;

create or replace function public.cc_update_sales(p_branch text,p_period date,p_target integer,p_actual integer)
returns void language plpgsql security definer set search_path=public as $$
begin
 if public.cc_role() not in ('admin','ejecutivo') then raise exception 'Solo Ejecutivo o Administrador'; end if;
 if p_target<0 or p_actual<0 then raise exception 'Cifras inválidas'; end if;
 insert into public.cc_sales(branch_code,period,target_pieces,actual_pieces,updated_by)
 values(p_branch,date_trunc('month',p_period)::date,p_target,p_actual,auth.uid())
 on conflict(branch_code,period) do update
 set target_pieces=excluded.target_pieces,actual_pieces=excluded.actual_pieces,updated_by=auth.uid(),updated_at=now();
end $$;

-- Nadie debe acceder como anon a RPC de seguridad.
revoke all on function public.cc_plan(uuid,text,date),public.cc_cancel_assignment(uuid,text),
public.cc_evidence_ok(text),public.cc_checkin(uuid,text,double precision,double precision,double precision),
public.cc_checkout(uuid,text,double precision,double precision,double precision),public.cc_break(uuid,boolean),
public.cc_close_report(uuid,text,integer,text,text,text,text),public.cc_supervisor_close(date,text),
public.cc_authorized_close(uuid,text),public.cc_update_sales(text,date,integer,integer) from public,anon;
grant execute on function public.cc_plan(uuid,text,date),public.cc_cancel_assignment(uuid,text),
public.cc_checkin(uuid,text,double precision,double precision,double precision),
public.cc_checkout(uuid,text,double precision,double precision,double precision),public.cc_break(uuid,boolean),
public.cc_close_report(uuid,text,integer,text,text,text,text),public.cc_supervisor_close(date,text),
public.cc_authorized_close(uuid,text),public.cc_update_sales(text,date,integer,integer) to authenticated;
grant execute on function public.cc_role(),public.cc_can_read_user(uuid),public.cc_can_plan_user(uuid) to authenticated;

-- Las selfies se guardan en privado, bajo carpeta <uid>/<uuid>.jpg
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('cc-evidence','cc-evidence',false,1048576,array['image/jpeg'])
on conflict(id) do nothing;
create policy "cc evidence upload self" on storage.objects for insert to authenticated
with check(bucket_id='cc-evidence' and split_part(name,'/',1)=auth.uid()::text);
create policy "cc evidence read scoped" on storage.objects for select to authenticated
using(bucket_id='cc-evidence' and (
 split_part(name,'/',1)=auth.uid()::text
 or public.cc_role() in ('admin','direccion','gerencia','ejecutivo')
 or (public.cc_role()='supervisor' and exists(
   select 1 from public.cc_profiles p
   where p.id::text=split_part(name,'/',1) and p.supervisor_id=auth.uid()
 ))
));
-- realtime: la interfaz también refresca cada 30 segundos.
alter publication supabase_realtime add table public.cc_visits;
alter publication supabase_realtime add table public.cc_assignments;
