# ColchoCheck App · PWA conectada a Supabase

## Estado
Este código está **preparado para conexión**, pero aún **NO está operativo en la nube**: la organización de Supabase no tiene proyecto creado. Ninguna tabla ni función fue desplegada a Supabase. No ingresar empleados ni subir fotografías reales hasta completar y verificar los pasos de este documento.

## Archivos
- pwa/index.html: carátula y navegación responsive.
- pwa/app.js: inicio de sesión, roles, agenda, cámara, GPS, reportes, fotos y CSV.
- pwa/config.example.js: plantilla sin secretos (crear pwa/config.js).
- supabase/migrations/20261111_colchocheck_initial.sql: tablas, seguridad por perfil, RPC, Storage privado.
- supabase/functions/cc-admin-users/index.ts: crear/bloquear cuentas y restablecer contraseñas (server-only).

## Antes de poner en línea
1. En Supabase, organización **ColchoCheck**, crear un proyecto con plan gratuito si está disponible. Confirmar costo antes de crear si no es $0.
2. Revisar el SQL en Supabase SQL Editor y ejecutarlo en un **proyecto vacío**, una sola vez.
3. Crear primer usuario de administración desde **Supabase > Authentication > Users > Add User**, con el correo técnico exacto \`admin1.moss@users.colchocheck.example.com\`, una contraseña robusta y correo confirmado. Este correo es un alias para conservar el ID previo; Supabase Auth lo utiliza como identidad técnica. Como no es una casilla real, el restablecimiento por correo no funcionará; debe mantenerse una vía segura de recuperación en el panel.
4. Con el proyecto recién creado, ejecutar en SQL Editor (sustituir nombre si procede):
\`\`\`sql
insert into public.cc_profiles(id,user_code,full_name,role,active)
select id,'ADMIN1.MOSS','Administrador ColchoCheck','admin',true
from auth.users where email='admin1.moss@users.colchocheck.example.com'
on conflict(id) do nothing;
\`\`\`
5. Desplegar la función Edge \`cc-admin-users\`, con JWT verificable. Las variables internas \`SUPABASE_URL\`, \`SUPABASE_ANON_KEY\` y \`SUPABASE_SERVICE_ROLE_KEY\` deben estar disponibles únicamente **en el servidor**, nunca en la PWA ni GitHub.
6. Copiar \`pwa/config.example.js\` a \`pwa/config.js\`, introduciendo URL y \`sb_publishable_...\` de ese proyecto. No usar service role ni secreto. Si GitHub Pages necesita el archivo, es seguro exponer la **clave publicable** siempre que RLS y Storage privado estén activos y probados.
7. Publicar la carpeta \`pwa/\` con GitHub Pages o servicio de sitio estático HTTPS. GitHub Pages no protege el HTML (tu repositorio es público), pero los datos de los usuarios deben permanecer restringidos por Supabase RLS.
8. Probar con dos cuentas nuevas y dos teléfonos reales antes de usar asistencia oficial: promotor, supervisor y admin; fotografía+GPS, programación, check-in, check-out, reporte, permisos, cierre excepcional y CSV.
9. Importar las sucursales y objetivos solo después de conciliar las diferencias del directorio Excel. No subir contraseñas del Excel antiguo.

## Roles
- Promotor: ver su rol, meta de sucursal, entrar/salir con selfie y cerrar reporte.
- Supervisor: planear visitas para sí y sus promotores, monitorear su equipo, cierre diario.
- Ejecutivo: visualización total, actualizar metas/ventas, cierre autorizado.
- Gerencia/Dirección: visualización total y exportación, sin edición.
- Admin: alta/bloqueo/restablecimiento, sucursales, planeación, cierre, exportación. Las contraseñas **existentes nunca son recuperables** (solo visibles las nuevas mientras se capturan).

## Limitaciones presentes
- El check-in exige GPS con precisión <=300m y foto en bucket privado; geocerca de 100m se reserva a fase 2.
- El contador calcula permanencia a partir de hora registrada por Supabase; no equivale necesariamente a trabajo efectivo.
- CSV abre en Excel; todavía no es un archivo nativo XLSX.
- Las operaciones sensibles pasan por RPC/Edge Function. Debe hacerse auditoría y pruebas en un proyecto real antes de producción.
- Servicio gratuito puede suspenderse por inactividad o tener restricciones de cuota. Hacen falta reglas de conservación y respaldo antes de uso laboral formal.
- No hay trabajo offline sincronizado ni garantías de resistencia total a falsificación de GPS/selfies. Los reportes muestran los comprobantes autenticados por perfil.
- El primer usuario administrador requiere aprovisionamiento inicial en Supabase; **no existe registro público de administrador**.
- Se espera HTTPS para cámara, geolocalización y sesión.
- Las cuentas técnicas con el dominio \`example.com\` no reciben correos; se diseñaron para evitar solicitar email al promotor. Cambiar el esquema de recuperación si se necesitan correos de invitación.

## Seguridad
Este repositorio es **público**. Nunca colocar información de empleados, fotografías, contraseñas, secretos, base Excel original ni claves de administración en él. Si se utilizaron contraseñas anteriores en archivos públicos, rotarlas.
