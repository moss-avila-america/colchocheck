# ColchoCheck V2 | Plan de reconstrucción segura

**Estado:** Proyecto Supabase V2 creado y SQL validado; no se han migrado datos ni conectado la aplicación.
**Objetivo:** Una aplicación nueva, sencilla para promotores y supervisores, sin tocar la versión original hasta aprobar pruebas.

## Principios
- Conservar la aplicación y Supabase originales como respaldo de solo lectura durante la transición.
- Crear un segundo proyecto Supabase solo después de confirmar organización, cuota/costo real y región.
- **No copiar contraseñas ni secretos**, ni publicar llaves privadas en GitHub.
- Reutilizar requisitos de negocio, pero diseñar servicios y pantallas limpios y verificables.
- Datos ficticios en pruebas; traspasar datos reales únicamente después de validar seguridad, autorización y recuperación.
- Plan de reversión sencillo: mantener el sitio de producción apuntando al sistema antiguo hasta autorizar el corte.

## Primera entrega: conexión real y roles
1. Crear proyecto Supabase V2.
2. Comprobar acceso a SQL, REST PostgREST, autenticación y Storage por separado.
3. Aplicar esquema limpio con políticas RLS comprobadas: administrador, supervisor, promotor y lectura gerencial.
4. Crear usuarios piloto por un flujo administrativo seguro (contraseñas nuevas, no migración de credenciales).
5. Validar en Android e iPhone el inicio de sesión y la lectura del perfil.

## Segunda entrega: asistencia
- Agenda y sucursales asignadas.
- Check-in con foto, GPS y hora, con permisos reales y almacenamiento protegido.
- Cronómetro/tiempo efectivo y check-out con foto.
- Cierre con afluencia, ingresos de clientes y cuatro observaciones.
- Manejo de fallos de internet y aviso claro de registro pendiente.

## Tercera entrega: supervisión y gestión
- Programación de rutas y cobertura; cierre justificado por administrador.
- Indicadores de visitas y objetivos por sucursal; ventas y garantías.
- Importación revisada del directorio y objetivos desde fuentes originales.
- Exportación a Excel para personal autorizado y registro de auditoría.

## Criterios de aceptación antes de publicar
- REST responde HTTP 200/201 a pruebas autorizadas (con tokens de prueba).
- Roles de usuarios se respetan por RLS aun al consultar la API directamente.
- No es posible consultar datos de otra persona sin autorización.
- Fotos quedan en almacenamiento privado con acceso autorizado.
- Entrada y salida no se duplican al reintentar; las fechas/hora no dependen exclusivamente del reloj del teléfono.
- Prueba de un ciclo completo en Android/iPhone.
- Se confirma respaldo, integridad de datos migrados y procedimiento de reversión.

## Nota sobre el incidente previo
Proyecto afectado: ColchoCheck-GNC, referencia `sphvdggfbbsdfvaaelnx`.
Folio: `SU-552296`. Errores observados: PGRST002/PGRST003.
Crear un proyecto nuevo no garantiza que el problema no reaparezca: validar primero el servicio Data API.

## Decisiones pendientes del usuario
- Organización de Supabase donde crear V2 (la existente se llama `ColchoCheck`).
- Aprobar cualquier costo no nulo que la plataforma cotice.
- Momento de migración y publicación, después de las pruebas.

## Infraestructura V2 creada (2026-11-18)
- Organización: `ColchoCheck` (plan Free).
- Proyecto nuevo: `ColchoCheck V2`.
- Ref de Supabase V2: `hftqkghnloqsmuioiquq`.
- Región: `us-west-1`.
- Cotización recibida antes de crear: **USD $0/mes**.
- Estado confirmado: `ACTIVE_HEALTHY`.
- PostgreSQL: `17.12`, consulta SQL de solo lectura exitosa.
- Health advisors: sin alertas en el momento de la comprobación.
- Proyecto anterior `sphvdggfbbsdfvaaelnx`: conservado y activo.
- Pendiente: probar de extremo a extremo REST y Auth con credenciales de prueba y preparar esquema/RLS. Aún no se ha migrado ningún dato ni conectado la app V2 a producción.
