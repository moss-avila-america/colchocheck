# ColchoCheck Beta 0.7 | Plan de recuperación

## Estado y reglas de publicación
- La versión 0.6.1 en `main` y GitHub Pages debe permanecer operativa hasta probar esta rama.
- La rama `feature/supervision-portfolio-07` incorpora un panel preliminar de cobertura y un programador mensual que invoca la RPC existente `cc_plan`.
- No afirmar que las nuevas funciones están desplegadas o validadas en iPhone/Android antes de pruebas reales.
- No borrar ni sobrescribir registros de asistencia, fotografías o cuentas.
- Mantener persistencia de sesión y cronómetro de visitas corregidos en 0.6.1.

## Perfiles
- Promotor: rol diario asignado, foto y GPS en check-in/check-out, pausa, cierre comercial; piezas de su tienda, sin editar objetivos.
- Supervisor: seguimiento de promotores asignados; programación mensual de su equipo; hasta 10 visitas propias diarias; cartera local GDL y foránea; visitas de apoyo; garantías; cierre de jornada; piezas y pesos informativos.
- Ejecutivo: visión comercial y gestión autorizada de metas y Excel maestro.
- Gerencia y Dirección: tableros y supervisión de información autorizada, sin asumir permisos de escritura.
- Administrador: usuarios, asignaciones, contingencias y cierres autorizados. Contraseñas iniciales seguras, nunca exponer claves de servicio en el frontend.
- Las restricciones deben verificarse en RLS/RPC y Edge Functions, no solo ocultando botones.

## Supervisor
- Agenda diaria libre de hasta 10 visitas, mezclando tiendas y garantías. El máximo debe aplicarse en servidor a todas las modalidades, no solo al formulario.
- Tienda propia: cuenta para cobertura mensual únicamente con registro válido de visita del supervisor.
- Visita de apoyo a otra zona: cuenta en la agenda y bitácora, pero NO en cobertura de tiendas propias.
- Mostrar visitadas y pendientes de la cartera asignada, separadas en local GDL y foránea según directorio maestro (no inferir permanentemente solo por texto de ciudad).
- Objetivo y avance de piezas; objetivo de importes en pesos y avance en pesos solo cuando la fuente incluya el dato.
- Rol mensual de promotores con cambios de sucursal y cancelación/reprogramación auditados.
- Promotor normalmente en sucursal fija; cambios programados por supervisor autorizado.

## Garantías
- Inspección asociada a folio y tienda/cliente; fecha, responsable, notas y dictamen.
- Seis evidencias fotográficas obligatorias: etiqueta/serie, vista superior, daño, base/box, costuras/bordes, póliza/comprobante (validar categorías exactas con el prototipo antes de cerrar).
- Dictamen: Procede cambio por garantía (hundimiento/defecto), No procede (manchas/mal uso/base inadecuada), En revisión con planta.
- Almacenar imágenes en bucket privado con rutas por inspección, acceso controlado y bitácora.
- No crear registros de garantía ficticios ni considerar completada una inspección con fotos incompletas.

## Excel maestro y datos
- Cuatro pestañas: `Directorio Tiendas`, `USER`, `OBJETIVOS`, `AVANCE MES`.
- Relacionar estrictamente por `No_Tienda`; no confundir identificador con nombre comercial.
- Directorio: 76 sucursales en la base inicial, con coordenadas a verificar antes de geocercas estrictas.
- Metas y avances comerciales deben conservar origen, periodo y corte, no inventar cifras faltantes.
- Solo Ejecutivo y Administrador autorizados pueden cargar el maestro; Promotor nunca altera metas.
- Validación previa, resumen de altas/cambios/errores y confirmación antes de aplicar importaciones.
- No sobrescribir datos reales con semillas de demostración.

## Catálogo de colchones
- Super Colchones 2026: LANDER, SIDNEY, CLOUD, FORUM, GRAVITY, ROYAL, DERBY.
- Modelos anteriores: LEXUS PLUS, MIDLAND, SKY (mantener para históricos cuando corresponda; LEXUS PLUS es distinto de LEXUS).
- Otros históricos citados: FANCY, STYLE, LEXUS, SUPREME, SHERWOOD.
- El catálogo comercial debe vincularse al origen de venta y mantenerse separado de las visitas de asistencia. No crear metas por modelo sin fuente.

## Validaciones antes de fusionar
1. Autenticación y RLS de los seis roles; ningún promotor puede consultar información ajena no autorizada.
2. Agenda supervisor: 10 registros permitidos, undécimo rechazado por backend incluso para garantía.
3. Rol mensual: días seleccionados, sin duplicados, reprogramación auditada, sin permisos sobre promotores ajenos.
4. Cobertura propia excluye apoyo; clasificación local/foránea del directorio.
5. Garantía exige seis fotografías y dictamen válido, con acceso privado.
6. Importación de cuatro hojas conserva datos previos y muestra errores por No_Tienda.
7. Check-in/out, GPS, selfies, pausas, temporizador, cierre y recuperación de sesión en iOS/Android.
8. Confirmación del usuario antes de fusionar a `main`.
