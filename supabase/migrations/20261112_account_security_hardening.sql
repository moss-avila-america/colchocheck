-- Security patch: deny access to blocked accounts on all read policies.
create or replace function public.cc_can_read_user(target uuid) returns boolean
language sql stable security definer set search_path=public
as $$
  select public.cc_role() is not null and (
    auth.uid()=target
    or public.cc_role() in ('admin','direccion','gerencia','ejecutivo')
    or (public.cc_role()='supervisor' and exists(
      select 1 from public.cc_profiles p where p.id=target and p.supervisor_id=auth.uid()
    ))
  )
$$;

-- Blocked accounts may not complete or mutate pending visits, even with a valid prior session.
create or replace function public.cc_checkout(p_visit uuid,p_photo text,p_lat double precision,p_lng double precision,p_accuracy double precision)
returns void language plpgsql security definer set search_path=public as $$
declare v public.cc_visits%rowtype;
begin
 if public.cc_role() not in ('promotor','supervisor') then raise exception 'Cuenta no autorizada'; end if;
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
 if public.cc_role() not in ('promotor','supervisor') then raise exception 'Cuenta no autorizada'; end if;
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
 if public.cc_role()<>'promotor' then raise exception 'Cuenta no autorizada'; end if;
 if not exists(select 1 from public.cc_visits where id=p_visit and user_id=auth.uid() and status='awaiting_report')
 then raise exception 'Primero registra la salida'; end if;
 if p_afluencia not in ('Nula','Baja','Media','Alta') or p_ingresos not between 0 and 9999 then raise exception 'Valores inválidos'; end if;
 if greatest(length(p_venta_america),length(p_venta_competencia),length(p_presupuesto_america),length(p_presupuesto_competencia))>140 then raise exception 'Límite 140 caracteres'; end if;
 insert into public.cc_reports(visit_id,afluencia,ingresos,venta_america,venta_competencia,presupuesto_america,presupuesto_competencia)
 values(p_visit,p_afluencia,p_ingresos,p_venta_america,p_venta_competencia,p_presupuesto_america,p_presupuesto_competencia);
 update public.cc_visits set status='complete' where id=p_visit;
 insert into public.cc_audit(actor_id,action,target) values(auth.uid(),'REPORTE_CIERRE',p_visit::text);
end $$;
