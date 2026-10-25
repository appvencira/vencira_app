# TRANSCRIPCIÓN DEL WHITEPAPER ORIGINAL — FUENTE DE CONSULTA

Documento: «White paper: agenda de vencimientos externos para mediadores de seguros»; @Bibroker Mediadores, S.L.U., 18/10/2026. Original PDF facilitado por el promotor el 25/10/2026 (23 páginas).

**Importante**: este archivo es transcripción de texto extraído automáticamente de las 23 páginas, NO es el PDF binario ni preserva sus diagramas, tablas como objetos o maquetación. Para resolver dudas de diagramas, usar el PDF original. SHA-256 del PDF original: `7158c085a0771f1c09c19223284345899ef516394d4ddd77c3b63cdda5598c66` (828405 bytes).



---

## Páginas 1–5

<PARSED TEXT FOR PAGE: 1 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




White paper: agenda de vencimientos
externos para mediadores de seguros
  ​Oct 18, 2026       · ​@Bibroker Mediadores, S.L.U.

Especificación funcional de la versión 1 de una app para móvil, tablet y ordenador que
avisa a agentes y corredores de seguros de los vencimientos de las pólizas que sus
clientes y candidatos tienen contratadas fuera de su cartera. Su fin es que el mediador
notifique la no renovación a tiempo y capte esas pólizas. Recoge las decisiones aprobadas
por el promotor; lo que sigue abierto aparece marcado como pendiente.


1. Qué es y qué no es
La app convierte cada póliza externa de un cliente o candidato en una cadena de avisos
hasta su vencimiento. Así el mediador notifica a tiempo la no renovación y ofrece su
alternativa.

Problema que resuelve. Para que una póliza no se renueve sola, el tomador debe oponerse
por escrito con al menos un mes de antelación al vencimiento (art. 22.2 de la Ley 50/1980,
de Contrato de Seguro). Si el mediador se acuerda tarde, la póliza se prorroga y la
oportunidad se pierde un año entero.

Usuarios. Agentes y corredores de seguros en España: profesionales que trabajan solos,
agencias y corredurías con equipos de empleados, colaboradores o auxiliares externos.

Lo que es:

     Una agenda tipo papel, organizada por días, centrada en vencimientos.
     Dos entradas, cada una con su color: vencimientos externos de clientes y
     vencimientos externos de candidatos.
     Avisos configurables por póliza, con una pregunta de control antes de la fecha límite
     legal.
     Sincronizada entre móvil, tablet y ordenador.

Lo que no es:

     No es un CRM ni un programa de gestión de correduría: no lleva fichas de clientes,
     cobros, comisiones ni siniestros.
     No gestiona la cartera propia: las pólizas que el usuario ya intermedia quedan fuera.
     No se conecta con aseguradoras en la versión 1.
     No redacta ni envía la carta de no renovación en la versión 1; queda como extensión de
     pago (apartado 15).



                                                                                       Page 1 of 23

<PARSED TEXT FOR PAGE: 2 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




2. Glosario
Estos términos se usan con el mismo sentido en todo el documento y deben usarse igual
en la interfaz.


  Término                                  Significado

  Cuenta                                   Unidad de suscripción: Individual o Equipo. Todos
                                           los datos pertenecen a la cuenta.

  Administrador                            Titular de una cuenta Equipo. Ve y gestiona todo lo
                                           de la cuenta y tiene también su propia agenda.

  Usuario                                  Miembro de una cuenta Equipo dado de alta por el
                                           administrador. Solo ve lo suyo.

  Anotación                                Cada registro de la agenda. Corresponde a una
                                           póliza externa con su fecha de vencimiento.

  Entrada                                  Tipo de anotación: Clientes (póliza que un cliente
                                           del usuario tiene fuera de su cartera) o Candidatos
                                           (póliza de un futuro cliente). Cada entrada tiene su
                                           color.

  Fecha de vencimiento                     Fin del periodo en curso de la póliza externa. Todos
                                           los avisos se cuentan hacia atrás desde esta fecha.

  Aviso                                    Recordatorio programado un número de días antes
                                           del vencimiento, con un motivo.

  Motivo                                   Texto corto que acompaña a un aviso, elegido de
                                           una lista editable.

  Fecha límite legal                       Un mes antes del vencimiento, contado de fecha a
                                           fecha. No se muestra en la agenda: solo actúa como
                                           tope (apartado 8).

  Pregunta de control                      "¿Se ha notificado a la aseguradora su no
                                           renovación?", que aparece en el último aviso antes
                                           de la fecha límite legal.

  Cierre                                   Desenlace final de una anotación: Conseguido, No
                                           aceptó, Aún sin decidir o Descartar (apartado 9).

  Archivo                                  Lugar donde quedan las anotaciones cerradas
                                           como Conseguido o Descartar. Fuera de la agenda
                                           y con borrado automático a los 2 años.




                                                                                                  Page 2 of 23

<PARSED TEXT FOR PAGE: 3 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




3. Versiones y permisos
Hay una sola app con dos versiones de suscripción: Individual (un usuario) y Equipo (un
administrador con uno o más usuarios). La suscripción activa unas funciones u otras.

     Paso de Individual a Equipo sin perder datos. El usuario individual cambia de
     suscripción, pasa a ser administrador y conserva toda su agenda.
     Las anotaciones pertenecen a la cuenta, no al usuario que las crea. Al dar de baja a un
     usuario, pierde el acceso al instante y el administrador reasigna sus anotaciones.
     El administrador también trabaja: tiene su propia agenda y recibe sus propios avisos,
     además de ver la del equipo.




                                                                                      Page 3 of 23

<PARSED TEXT FOR PAGE: 4 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




  Acción                                             Individual           Administrador             Usuario
                                                                          (Equipo)                  (Equipo)

  Crear, editar y cerrar                             Sí                   Sí                        Sí
  anotaciones propias

  Ver anotaciones de otros                           —                    Sí, con el nombre de      No
  usuarios                                                                quien la lleva

  Asignar y reasignar                                —                    Sí                        No
  anotaciones

  Dar de alta y de baja                              —                    Sí                        No
  usuarios

  Fijar avisos y listas                              Sí, para su          Sí, para todo el equipo   No: usa los del
  desplegables por defecto                           cuenta                                         equipo

  Ajustar los avisos de una                          Sí                   Sí                        Sí, en las suyas
  anotación concreta

  Recibir avisos                                     Los suyos            Los suyos                 Los suyos

  Elegir hora de aviso y sonido                      Sí                   Sí                        Sí

  Consultar el historial (solo                       Sus                  Todas                     Sus anotaciones
  web)                                               anotaciones

  Resumen de resultados                              El suyo              Por usuario y total       Pendiente de
  (solo web)                                                                                        decidir

  Importar y exportar Excel                          Sí                   Sí                        Pendiente de
  (solo web)                                                                                        decidir

  Configurar el plazo de                             Sí                   Sí                        No
  borrado del archivo


Las dos casillas pendientes están en el apartado 18. Recomendación: que un usuario no
pueda exportar a Excel, para evitar que se lleve la lista de candidatos al marcharse.


4. Plataformas y sincronización
La app funciona en móvil y tablet (iOS y Android) y en ordenador mediante una versión
web, con los mismos datos sincronizados al instante en todos los dispositivos.




                                                                                                                Page 4 of 23

<PARSED TEXT FOR PAGE: 5 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




  Dispositivo                                    Cómo se usa                                   Sin
                                                                                               conexión

  Móvil y tablet iOS                             App descargada de App Store                   Sí

  Móvil y tablet Android                         App descargada de Google Play                 Sí

  Ordenador Windows o                            Versión web en el navegador (Chrome, Edge,    No
  Mac                                            Safari), con opción de dejar un icono en el
                                                 escritorio. No hay programa instalable.


Uso sin conexión (móvil y tablet). Sin cobertura se puede consultar la agenda, crear y
editar anotaciones, hacer fotos y responder a los avisos. Todo se sincroniza solo al
recuperar la conexión.

Los avisos saltan aunque no haya cobertura. Deben quedar programados en el propio
dispositivo, no depender de que el servidor los envíe en ese momento.

Recomendación técnica, a validar por el desarrollador: una sola base de código
multiplataforma para iOS, Android y web. Fue el motivo para elegir la versión web en
ordenador: abarata el desarrollo y las actualizaciones llegan a todos a la vez.

Queda por definir qué ocurre si dos dispositivos modifican la misma anotación sin
conexión (apartado 18).


5. La agenda (pantalla principal)
La pantalla principal es una agenda tipo papel: se abre siempre en la página de hoy y
muestra lo que el usuario tiene que hacer ese día. No hay pantallas de fichas de clientes.




                                                                                                     Page 5 of 23


---

## Páginas 6–10

<PARSED TEXT FOR PAGE: 6 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




maqueta de la página del día en el móvil · datos de ejemplo

Maqueta orientativa con datos inventados: el diseño visual definitivo corresponde al
desarrollador.

Elementos de la página del día:

 1. Cabecera con la fecha completa y el número de anotaciones de ese día.
 2. Franja de la semana debajo, con el día que se está viendo resaltado.
 3. Pasar página: deslizar el dedo a la izquierda o a la derecha lleva al día siguiente o al
     anterior. En ordenador, con flechas.
 4. Lista del día: cada anotación muestra el color de su entrada, el nombre y el nick, la
     modalidad, la aseguradora, la fecha de vencimiento y el motivo del aviso. Al tocarla se
     abre.
 5. Botón "Hoy": vuelve a la página del día actual.
 6. "Ver mes": calendario mensual con puntos de color en los días que tienen algo. Al tocar
     un día se abre su página.



                                                                                          Page 6 of 23

<PARSED TEXT FOR PAGE: 7 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




 7. Botón +: crea una anotación nueva.

Qué aparece en cada día: los avisos programados para ese día, los "recuérdamelo" que
caen en él y, el día del vencimiento, la propia anotación con sus botones de cierre
(apartado 9).

Filtros, en una barra sobre la agenda y combinables entre sí:

     Entrada: Clientes, Candidatos o ambas, cada una con su color.
     Modalidad.
     Aseguradora.
     Usuario: solo para el administrador en la versión Equipo.

Buscador por nombre, nick o número de póliza, que abre directamente la anotación
encontrada.

Falta decidir qué pasa con un aviso que el usuario no atiende ese día (apartado 18).


6. La anotación
Cada anotación es una póliza externa con su vencimiento. Si una persona tiene tres
pólizas fuera, tiene tres anotaciones. No existe una ficha de cliente común.


  Campo                                Tipo                               Obligatorio   Comportamiento
                                                                          (propuesta)

  Entrada                              Clientes o                         Sí            Define el color en la agenda.
                                       Candidatos

  Nombre y apellidos                   Texto                              Sí            Al escribir, sugiere personas
  o razón social                                                                        de otras anotaciones para
                                                                                        copiar sus datos.

  Apodo o nick                         Texto                              No            Se muestra junto al nombre
                                                                                        y se puede buscar.

  Teléfono                             Teléfono                           No            En móvil: "Elegir de mis
                                                                                        contactos" y "Guardar en
                                                                                        mis contactos".

  Email                                Email                              No            Sin botón de envío.

  Modalidad                            Lista desplegable                  No            Precargada; sirve de filtro.
                                       editable

  Número de póliza                     Texto                              No            Se puede buscar.




                                                                                                                 Page 7 of 23

<PARSED TEXT FOR PAGE: 8 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




  Campo                                Tipo                               Obligatorio   Comportamiento
                                                                          (propuesta)

  Aseguradora                          Lista desplegable                  No            Precargada con las
                                       con búsqueda                                     aseguradoras del mercado
                                                                                        español; ampliable; sirve de
                                                                                        filtro.

  Fecha de                             Fecha                              Sí            Base de todos los avisos y
  vencimiento                                                                           de la fecha límite legal.

  Notas                                Texto largo                        No            Ejemplos: "mejorar precio",
                                                                                        "incluir a sus hijos en el
                                                                                        seguro de salud".

  Archivos                             Imágenes y PDF,                    No            Cada archivo con un nombre
                                       varios                                           corto: "Póliza", "Recibo",
                                                                                        "Carnet".

  Avisos                               Lista                              Automático    Se cargan los avisos por
                                                                                        defecto (apartado 7).

  Usuario asignado                     Usuario de la                      Automático    Solo en Equipo: quien la
                                       cuenta                                           crea; el administrador puede
                                                                                        cambiarlo.


Autocompletado de datos personales. Si al escribir el nombre o el teléfono coincide con
otra anotación, la app ofrece copiar nick, teléfono y email. El usuario puede ignorar la
sugerencia. Los datos se copian; cambiar el teléfono en una anotación no cambia las
demás.

Candidato que pasa a cliente. Tras un cierre "Conseguido", las nuevas anotaciones de esa
persona entran por defecto como Clientes. Internamente la app necesita reconocer a la
persona, por ejemplo por teléfono o nombre, aunque no haya fichas visibles.

Contactos del teléfono. "Elegir de mis contactos" rellena nombre, teléfono y email del
contacto elegido. "Guardar en mis contactos" crea en el móvil el contacto de una
anotación. No hay sincronización automática: la app no debe leer la agenda completa del
teléfono, solo el contacto que el usuario elige. En ordenador y tablet el teléfono es un
campo normal.

Lista de modalidades por defecto: Autos, Motos, Patinetes, Hogar, Comercio, Decesos,
Salud, Vida, Accidentes, Responsabilidad civil, Comunidades y Otros. Se pueden añadir,
renombrar o borrar opciones.




                                                                                                               Page 8 of 23

<PARSED TEXT FOR PAGE: 9 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




Lista de aseguradoras. Se busca escribiendo las primeras letras. Fuente sugerida para
precargarla: el registro público de entidades aseguradoras de la Dirección General de
Seguros y Fondos de Pensiones. Esta lista será la base de datos de direcciones que usará
la futura carta de no renovación.

Archivos. En móvil: foto con la cámara en el momento o desde la galería. En ordenador:
subir PDF o imágenes arrastrándolos. El tamaño máximo por archivo y el espacio por
cuenta están pendientes (apartado 18).


7. Avisos y notificaciones
Cada anotación trae por defecto tres avisos, a 60, 45 y 35 días antes de su fecha de
vencimiento. Los días se cuentan siempre hacia atrás desde la fecha de vencimiento de la
póliza externa.

Ejemplo con una póliza que vence el 15 de marzo de 2027:


  Aviso                                                         Fecha en que salta

  60 días                                                       14 de enero de 2027

  45 días                                                       29 de enero de 2027

  35 días (con la pregunta de control)                          8 de febrero de 2027


Configuración por defecto. En Configuración se fijan los avisos que se cargan en cada
anotación nueva: días y motivo de cada uno. En la versión Equipo los fija el administrador
para todos.

Ajuste en cada anotación. Cada aviso se cambia con un selector giratorio de días. Se
pueden añadir avisos o quitar alguno sin afectar al resto ni a otras anotaciones. Ejemplo
real: un aviso a 45 días para enviar la notificación y otro a 15 días para pedir un
videoperitaje que la nueva aseguradora no admite antes.

Motivo. Cada aviso lleva un motivo corto que aparece en la notificación. Se elige de una
lista desplegable que el usuario puede editar y ampliar. Lista inicial mínima: "Enviar
notificación de no renovación", "Pedir videoperitaje" y "Pedir documentación al cliente". El
motivo por defecto de cada uno de los tres avisos está pendiente (apartado 18).

Hora y sonido. Cada usuario elige la hora a la que saltan sus avisos (por defecto, 9:00) y si
la notificación suena o no.

Canales:

     Móvil y tablet: notificación del sistema, aunque la app esté cerrada.




                                                                                         Page 9 of 23

<PARSED TEXT FOR PAGE: 10 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




     Ordenador: notificación del navegador si la versión web está abierta, y un contador de
     avisos pendientes junto al icono.
     Email resumen diario: opcional y desactivado por defecto. Cada mañana, "Hoy tienes 3
     avisos", con la lista.

Botones de cada aviso. En la notificación del móvil caben pocos botones (Android admite
como máximo tres), así que son:


  Botón                    Qué hace

  Completada               Marca ese aviso como hecho. Los demás avisos de
                           la anotación siguen su curso.

  Mañana                   Vuelve a avisar al día siguiente, a la hora
                           configurada, con el mismo motivo.

  Otro día…                Abre el selector de días (2, 3, 5 o los que se elijan) y
                           vuelve a avisar ese día.


Dentro de la app, al abrir el aviso aparecen los mismos tres botones y un acceso directo a
los archivos y las notas de la anotación.



8. Pregunta de control y fecha límite legal
Antes de la fecha límite legal, la app obliga a confirmar si la no renovación ya se ha
notificado. Si no, programa un nuevo aviso que nunca puede caer después de esa fecha.


Fecha límite legal: regla de cálculo
El tomador debe oponerse a la prórroga mediante notificación escrita con al menos un
mes de antelación a la conclusión del periodo en curso (art. 22.2 de la Ley 50/1980, de 8 de
octubre, de Contrato de Seguro, en la redacción vigente desde el 1 de enero de 2016). Los
plazos por meses se computan de fecha a fecha. Si no hay día equivalente, el plazo expira
el último día del mes (art. 5.1 del Código Civil).

Regla que debe aplicar la app:

 1. Fecha límite = el mismo día del mes anterior al vencimiento.
 2. Si ese día no existe en el mes anterior, se toma el último día de ese mes. Es la opción
     más prudente.
 3. La fecha límite no se muestra en la agenda: solo sirve de tope.




                                                                                         Page 10 of 23


---

## Páginas 11–15

<PARSED TEXT FOR PAGE: 11 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




  Vencimiento               Fecha límite legal              Días de antelación

  15/03/2027                15/02/2027                      28

  31/03/2027                28/02/2027                      31

  31/05/2027                30/04/2027                      31

  15/08/2027                15/07/2027                      31


Por eso un mes no equivale a 30 días: un aviso a 30 días llegaría tarde en tres de estos
cuatro casos.


La pregunta de control
Dónde aparece: en el último aviso de la anotación cuya fecha sea anterior a la fecha límite
legal. Con los avisos por defecto es el de 35 días. Si el usuario mueve o borra ese aviso, la
pregunta pasa al último aviso que quede antes de la fecha límite, para que nunca se
pierda.

Texto: "¿Se ha notificado a la aseguradora su no renovación?"


  Respuesta             Opciones                                                 Qué hace la app

  Sí                    Avisada por el cliente · La                              Registra la opción en el historial con
                        aseguradora no renueva · Notificado                      fecha, hora y usuario. La anotación
                        por mí                                                   sigue en la agenda hasta su cierre.

  No                    Avísame dentro de [selector de días]                     Crea el aviso "Comunicar no
                                                                                 renovación de [nombre del cliente]"
                                                                                 en la fecha elegida.


Tope del selector. Si la respuesta es "No", el selector no permite elegir una fecha posterior
a la fecha límite legal. Si la fecha límite es hoy o ya ha pasado, lo indica en rojo.

Margen recomendado. La app debe advertir que no conviene apurar hasta el último día:
un burofax o un correo certificado tardan en llegar y la aseguradora puede exigir prueba
de la entrega.


9. Cierre de la anotación
El día del vencimiento la anotación aparece en la agenda con cuatro botones de cierre.
Propuesta: que esos botones estén también disponibles antes, desde la propia anotación,
por si el desenlace llega antes.



                                                                                                                  Page 11 of 23

<PARSED TEXT FOR PAGE: 12 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




  Botón                                                                   Qué hace

  Conseguido                                                              La póliza se ha contratado con el usuario. La
                                                                          anotación sale de la agenda y pasa al archivo
                                                                          como ganada, porque a partir de ahí se
                                                                          gestiona en el programa de la correduría. Si
                                                                          era un candidato, la persona queda marcada
                                                                          como cliente.

  No aceptó, volver a intentarlo el año que                               La anotación sigue en la agenda. La fecha de
  viene                                                                   vencimiento pasa al año siguiente, se
                                                                          mantienen notas y archivos y se cargan de
                                                                          nuevo los avisos por defecto.

  Aún sin decidir, recuérdamelo en [selector                              El cliente no ha dado respuesta definitiva. La
  de días]                                                                anotación sigue abierta y vuelve a aparecer
                                                                          el día elegido.

  Descartar                                                               La anotación sale de la agenda y pasa al
                                                                          archivo. Se puede recuperar mientras siga en
                                                                          él.


Cada cierre queda registrado en el historial con fecha, hora y usuario. Las anotaciones
archivadas se borran automáticamente a los 2 años del cierre (apartado 12).




                                                                                                                  Page 12 of 23

<PARSED TEXT FOR PAGE: 13 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




10. Ciclo de vida de una anotación




ciclo de vida de una anotación · avisos, pregunta de control y cuatro cierres

Si la respuesta es "No", la app repite la pregunta en la fecha elegida, siempre antes de la
fecha límite legal. "No aceptó" devuelve la anotación al principio del ciclo un año después.



11. Solo en la versión web
Tres funciones existen únicamente en la versión web del ordenador y no aparecen en
móvil ni tablet: el historial, Excel y el resumen de resultados.




                                                                                      Page 13 of 23

<PARSED TEXT FOR PAGE: 14 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




Historial de cada anotación
Cada anotación guarda un registro automático que nadie puede modificar ni borrar. Cada
entrada lleva fecha, hora y usuario:

     Creación de la anotación.
     Avisos que han saltado.
     Respuesta a la pregunta de control y opción elegida.
     Cada "Mañana", "Otro día" y "recuérdamelo".
     Cambios de la fecha de vencimiento.
     Cierre y su tipo.
     Reasignaciones a otro usuario (versión Equipo).

Para qué sirve: como prueba si un cliente reclama que no se le avisó, y como control del
equipo para el administrador. Cada usuario ve el historial de sus anotaciones; el
administrador, el de todas.


Importar y exportar en Excel
Importar. La app ofrece una plantilla Excel con estas columnas: Entrada, Nombre y
apellidos o razón social, Nick, Teléfono, Email, Modalidad, Número de póliza, Aseguradora,
Fecha de vencimiento, Notas y, en Equipo, Usuario asignado. Al subirla se crean todas las
anotaciones de golpe, con los avisos por defecto. Antes de importar, la app muestra las
filas con errores (falta un campo obligatorio, fecha no válida) para corregirlas. Los
archivos y fotos no se importan.

Exportar. Descarga en Excel las anotaciones visibles con los filtros aplicados. Ejemplo:
"candidatos de autos que vencen en marzo".


Resumen de resultados
Contadores por periodo (mes, trimestre o año) y, en Equipo, por usuario y total.
Definiciones propuestas:


  Contador                    Qué cuenta

  Conseguidas                 Cierres "Conseguido" con fecha de cierre en el
                              periodo

  No aceptadas                Cierres "No aceptó" con fecha de cierre en el
                              periodo

  Descartadas                 Cierres "Descartar" con fecha de cierre en el
                              periodo




                                                                                        Page 14 of 23

<PARSED TEXT FOR PAGE: 15 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




  Contador                    Qué cuenta

  Pendientes                  Anotaciones con vencimiento en el periodo que
                              siguen sin cerrar


Sirve para medir cuánto negocio trae la agenda y, en las corredurías grandes, cómo
convierte cada agente.


12. Seguridad y conservación de datos
La app guarda datos personales de terceros y fotos de documentos como el DNI, así que
la seguridad es obligatoria por protección de datos y, además, un argumento de venta.


Acceso

  Medida                                            Detalle

  Identificación                                    Email y contraseña.

  Verificación en dos pasos                         Código al móvil o al email. Obligatoria para el
                                                    administrador, opcional para los usuarios. En la
                                                    versión Individual, pendiente (propuesta:
                                                    obligatoria).

  Desbloqueo en móvil                               Huella o Face ID, para no escribir la contraseña
                                                    cada vez.

  Bloqueo automático                                Tras un tiempo sin uso configurable, por ejemplo 5
                                                    minutos.

  Cifrado                                           Datos cifrados en el envío y en el almacenamiento.

  Ubicación de los servidores                       Dentro de la Unión Europea.

  Copias de seguridad                               Necesarias; frecuencia y lugar a definir por el
                                                    desarrollador, también en la UE.



Conservación y borrado
     Borrado automático del archivo: a los 2 años del cierre por defecto. El administrador (o
     el usuario Individual) puede cambiar el plazo.
     Avisos antes del borrado: el primero 3 meses antes y el segundo 1 mes antes, con la
     lista de lo que se va a borrar.




                                                                                                         Page 15 of 23


---

## Páginas 16–20

<PARSED TEXT FOR PAGE: 16 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




     Borrado manual inmediato de cualquier anotación, por ejemplo cuando una persona
     pide que se eliminen sus datos.
     El plazo concreto debe validarlo cada mediador con su delegado o asesor de
     protección de datos. La app solo da la herramienta.

Bloqueo antes de la destrucción (a validar). Quien borra o rectifica datos está obligado a
bloquearlos: se identifican y reservan, sin uso, a disposición solo de jueces, tribunales,
Ministerio Fiscal o administraciones competentes durante el plazo de prescripción, y
después se destruyen (art. 32 de la Ley Orgánica 3/2018, de Protección de Datos
Personales y garantía de los derechos digitales). Recomendación: que "borrar" pase
primero a un estado bloqueado, invisible para los usuarios, y la destrucción física llegue al
terminar el plazo que fije el mediador. Debe confirmarlo un asesor de protección de datos
antes de programarlo.


13. Idiomas
La versión 1 estará en castellano y catalán. Otros idiomas se añadirán si el producto
funciona en España.

Requisito técnico: la app debe estar preparada desde el principio para añadir idiomas sin
rehacerla. Todos los textos de la interfaz, avisos, notificaciones, emails y plantillas Excel
van en archivos de traducción, nunca escritos dentro del código. Las fechas se muestran
en el formato del idioma elegido.


14. Suscripción y cobro (sin decidir)
El modelo de cobro no está decidido. Estas son las opciones planteadas, para que el
desarrollo deje preparada la estructura sin cerrar importes.


  Elemento                                 Opción planteada                                Estado

  Prueba gratuita                          30 días con todas las funciones, sin pedir      Sin decidir
                                           tarjeta al empezar

  Periodicidad                             Mensual o anual, con descuento en la anual      Sin decidir

  Precio Individual                        Precio fijo                                     Importe sin
                                                                                           definir

  Precio Equipo                            Precio base que incluye al administrador, más   Importes sin
                                           una cantidad por cada usuario añadido           definir

  Medio de pago                            Tarjeta o domiciliación desde la web            Sin decidir




                                                                                                         Page 16 of 23

<PARSED TEXT FOR PAGE: 17 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




  Elemento                                  Opción planteada                               Estado

  Dónde se contrata                         Web o compra dentro de la app                  Sin decidir

  Fin de prueba o                           Qué puede hacer el usuario con sus datos       Sin decidir
  impago


Aviso sobre las tiendas. Apple y Google tienen normas propias y comisiones para las
suscripciones que se contratan dentro de la app. El desarrollador debe verificar qué
fórmula está permitida y cuál es más barata antes de decidir dónde se cobra. Este punto
no está comprobado.


15. Extensiones futuras de pago
Dos funciones quedan fuera de la versión 1 y se ofrecerán como actualizaciones de pago si
el producto tiene suscriptores. Conviene diseñar la versión 1 sin cerrarles la puerta.


A. Carta de no renovación
La app generaría la carta de oposición a la prórroga y gestionaría su firma y su envío.


  Dato de la carta                     Persona física                             Persona jurídica

  Identificación                       Nombre y apellidos                         Razón social

  Documento                            DNI                                        CIF

  Aseguradora                          Sí; su dirección se carga sola desde la    Igual
                                       base de datos de aseguradoras

  Número de póliza                     Sí                                         Sí

  Fecha de                             Sí                                         Sí
  vencimiento

  Firma                                Del cliente                                Del representante de la
                                                                                  empresa


Flujo que siguen hoy la mayoría de agentes y corredurías:

 1. Se genera la carta con los datos de la anotación.
 2. Se envía al cliente por email para que la firme digitalmente.
 3. Vuelve firmada con el certificado electrónico de la firma.
 4. Se adjunta copia del DNI del cliente.
 5. Se envía a la aseguradora por correo electrónico certificado.



                                                                                                         Page 17 of 23

<PARSED TEXT FOR PAGE: 18 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




Requiere contratar servicios de terceros de firma electrónica y de entrega certificada.
Marco aplicable: el art. 25 del Reglamento (UE) 910/2014 (eIDAS), modificado por el
Reglamento (UE) 2024/1183, impide negar efectos jurídicos o valor de prueba a una firma
por ser electrónica, y equipara la firma electrónica cualificada a la manuscrita.
Recomendación: elegir prestadores cualificados de servicios de confianza.

Cada correduría hace este trámite de forma distinta, así que el flujo deberá poder
adaptarse.


B. Lectura automática de pólizas
Al subir la foto o el PDF de la póliza, la app leería la aseguradora, el número de póliza y la
fecha de vencimiento, y rellenaría esos campos. El usuario solo los revisa y confirma.

Si la lectura la hace un servicio externo de inteligencia artificial, ese proveedor tratará
datos personales por cuenta del mediador. Deberá estar cubierto por contrato y tratar los
datos en la UE o con garantías equivalentes.


16. Marco legal que el desarrollo debe respetar
Las normas que condicionan el diseño son la Ley de Contrato de Seguro (plazos), el RGPD
y la LOPDGDD (datos personales) y, para clientes grandes, DORA. No sustituye el
asesoramiento de un abogado o de un delegado de protección de datos.


  Norma                                  Artículo                         Qué implica para la app    Certeza

  Ley 50/1980, de 8 de                   22.2, redacción de               Oposición a la prórroga    Alta
  octubre, de Contrato                   la Ley 20/2015                   por escrito: el tomador,
  de Seguro (BOE                         vigente desde el                 con al menos un mes; el
  17/10/1980)                            1/1/2016                         asegurador, con dos.
                                                                          Base de la fecha límite
                                                                          (apartado 8).

  Ley 50/1980, de                        22, último apartado              Sus reglas no se           Alta
  Contrato de Seguro                                                      aplican en lo
                                                                          incompatible con el
                                                                          seguro de vida. La
                                                                          fecha límite puede no
                                                                          servir para pólizas de
                                                                          Vida.




                                                                                                               Page 18 of 23

<PARSED TEXT FOR PAGE: 19 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




  Norma                                  Artículo                         Qué implica para la app    Certeza

  Código Civil                           5.1                              Plazos por meses, de       Alta
                                                                          fecha a fecha; sin día
                                                                          equivalente, el último
                                                                          del mes.

  Reglamento (UE)                        28                               El mediador es             Alta
  2016/679 (RGPD)                                                         responsable del
                                                                          tratamiento y la
                                                                          empresa titular de la
                                                                          app, encargada. Hace
                                                                          falta contrato de
                                                                          encargo; los
                                                                          proveedores de
                                                                          alojamiento, email o IA
                                                                          son subencargados y
                                                                          requieren autorización.

  RGPD                                   32 y 33.2                        Seguridad adecuada al      Alta
                                                                          riesgo. El encargado
                                                                          avisa al responsable de
                                                                          cualquier brecha sin
                                                                          dilación indebida.

  RGPD                                   5.1.c y 5.1.e                    Minimización (fotos de     Alta
                                                                          DNI solo si hacen falta)
                                                                          y plazo de
                                                                          conservación limitado:
                                                                          justifica el borrado
                                                                          automático.

  RGPD                                   13, 14 y 17                      El mediador debe           Alta
                                                                          informar a clientes y
                                                                          candidatos y atender la
                                                                          supresión: justifica el
                                                                          borrado manual.

  RGPD                                   Capítulo V (44 a                 Datos fuera de la UE       Alta
                                         50)                              solo con garantías: por
                                                                          eso servidores en la
                                                                          UE.

  Ley Orgánica 3/2018,                   32                               Bloqueo de los datos al    Alta en la norma; su
  de 5 de diciembre                                                       borrarlos, antes de        aplicación a la app,
  (LOPDGDD; BOE                                                           destruirlos (apartado      a validar
  6/12/2018)                                                              12).



                                                                                                                  Page 19 of 23

<PARSED TEXT FOR PAGE: 20 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




  Norma                                  Artículo                         Qué implica para la app    Certeza

  Reglamento (UE)                        2.3.e                            Excluye a los              Alta en la
  2022/2554 (DORA)                                                        intermediarios que son     exclusión; media en
                                                                          micro, pequeña o           el detalle de
                                                                          mediana empresa. Las       cláusulas
                                                                          corredurías grandes sí
                                                                          están sujetas y exigirán
                                                                          cláusulas
                                                                          contractuales
                                                                          específicas a la app
                                                                          como proveedor
                                                                          tecnológico.

  Reglamento (UE)                        25                               Solo para la extensión     Alta
  910/2014 (eIDAS),                                                       de la carta (apartado
  modificado por el                                                       15).
  2024/1183

  Ley 34/2002, de                        10                               Información general del    Alta
  servicios de la                                                         prestador accesible en
  sociedad de la                                                          la web y la app.
  información


Interpretaciones distintas sobre la notificación. No hay criterio unánime sobre si basta
con enviar la oposición a tiempo o debe recibirse a tiempo. La Audiencia Provincial de
Granada (Sección 5.ª, sentencia 319/2018) dio por válida la remisión de la carta sin exigir
prueba de recepción. En la práctica, las aseguradoras suelen pedir prueba de la entrega.
Es jurisprudencia menor, no del Tribunal Supremo. Por eso la app recomienda margen y un
medio que acredite la recepción.

Quién firma la oposición. La oposición corresponde al tomador como parte del contrato.
Si el mediador la envía ("Notificado por mí"), debe contar con la firma o la autorización del
cliente.

Responsabilidad profesional. Si un aviso falla y la póliza del cliente se renueva, el cliente
puede reclamar al mediador, y este a la empresa de la app. Los términos de uso deben
dejar claro que la app es una ayuda y no sustituye el control del mediador. La empresa
titular debería contratar un seguro de responsabilidad civil profesional tecnológica y de
ciberriesgos.




                                                                                                                  Page 20 of 23


---

## Páginas 21–23

<PARSED TEXT FOR PAGE: 21 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




17. Nombre de la aplicación
El nombre está pendiente entre cuatro candidatos. En este documento la app se llama
provisionalmente "Agenda de vencimientos".


  Nombre                 Origen                                      A favor                   Riesgo detectado

  Asegurator             De "asegurar"                               Se entiende al instante   Coincide con el nombre
                                                                     en castellano y catalán   de otro proyecto del
                                                                                               promotor (una
                                                                                               plataforma de
                                                                                               captación para
                                                                                               corredurías); solo
                                                                                               encaja como familia de
                                                                                               marca. Fuera de España
                                                                                               puede no transmitir
                                                                                               nada.

  Vencia                 De "vencimiento"                            Corto y pronunciable      Ninguno en una
                                                                     en castellano, catalán,   búsqueda rápida
                                                                     inglés, portugués e
                                                                     italiano

  Renuo                  Latín: "me niego,                           Suena a "renew" y         Existe Renu:Wise, una
                         rechazo", como la no                        "renovar"                 app de caducidad de
                         renovación                                                            documentos de viaje,
                                                                                               de otro sector

  Lapso                  Castellano: "periodo de                     Corto y fácil             En el seguro anglosajón
                         tiempo"                                                               "lapse" es la póliza
                                                                                               caducada por impago:
                                                                                               connotación negativa
                                                                                               fuera de España


Antes de elegir, una búsqueda en internet no basta. Hay que comprobar el nombre como
marca en la Oficina Española de Patentes y Marcas y en la Oficina de Propiedad
Intelectual de la Unión Europea, en las clases 9 y 42 (software y servicios en la nube).
También el dominio y su disponibilidad en App Store y Google Play.


18. Decisiones pendientes y casos límite
Quedan 20 puntos abiertos: 14 los decide el promotor y 6 el desarrollador. Cada uno lleva
la propuesta de partida, que no está aprobada.




                                                                                                                  Page 21 of 23

<PARSED TEXT FOR PAGE: 22 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




Las decide el promotor
     Campos obligatorios. Propuesta: Entrada, Nombre y Fecha de vencimiento.
     Motivo por defecto de cada uno de los tres avisos (60, 45 y 35 días).
     Avisos no atendidos. Propuesta: siguen visibles como "Pendientes" en la parte
     superior de la página de hoy hasta que se respondan.
     Anotación creada tarde, cuando algún aviso por defecto ya habría pasado. Propuesta:
     no se crean avisos en el pasado; si la fecha límite está cerca o ha pasado, la pregunta de
     control sale al guardar la anotación, con aviso en rojo.
     Aviso "Comunicar no renovación de [nombre]". Propuesta: vuelve a mostrar la
     pregunta de control.
     Sin avisos antes de la fecha límite, porque el usuario los ha movido todos después.
     Propuesta: la app impide guardar o crea un aviso de control automático.
     Pólizas de Vida. Propuesta: advertencia al elegir esa modalidad, porque el plazo del art.
     22 puede no aplicarse.
     Usuarios de Equipo y el resumen de resultados. Propuesta: cada uno ve solo el suyo.
     Usuarios de Equipo y Excel. Recomendación: no pueden exportar.
     Usuarios de Equipo y las listas desplegables: ¿pueden añadir modalidades,
     aseguradoras o motivos?
     Verificación en dos pasos en Individual. Propuesta: obligatoria.
     Bloqueo antes de borrar (art. 32 LOPDGDD), a validar con un asesor de protección de
     datos.
     Nombre de la app entre los cuatro candidatos (apartado 17).
     Suscripción, precios y sociedad titular de la app. Recomendación: una sociedad
     distinta de la correduría.


Las decide el desarrollador
     Tecnología: base de código multiplataforma para iOS, Android y web.
     Conflictos de sincronización cuando dos dispositivos cambian la misma anotación sin
     conexión.
     Límites de archivos: tamaño máximo por archivo y espacio por cuenta.
     Copias de seguridad: frecuencia y ubicación dentro de la UE.
     Normas de App Store y Google Play para cobrar suscripciones (apartado 14).
     Proveedores de notificaciones, email y alojamiento, todos con contrato de subencargo
     de tratamiento.




                                                                                       Page 22 of 23

<PARSED TEXT FOR PAGE: 23 / 23>

White paper: agenda de vencimientos externos para mediadores de seguros




Fuentes
     Texto del art. 22 de la Ley 50/1980, de Contrato de Seguro, citado en la sentencia
     319/2018 de la Audiencia Provincial de Granada
     Consumo Responde (Junta de Andalucía): la póliza del contrato de seguro
     Legal Today: novedades introducidas en la Ley de Contrato de Seguro por la Ley
     20/2015
     Legálitas: plazo para dar de baja el seguro del coche
     Diccionario panhispánico del español jurídico (RAE): cómputo de plazos
     Górriz Gómez, "Acerca del cómputo de los plazos por meses", Revista FORO
     (Universidad Complutense)
     BOE: Ley Orgánica 3/2018, de Protección de Datos Personales y garantía de los
     derechos digitales
     Autoridad Catalana de Protección de Datos: resolución PT 6/2023 sobre el bloqueo del
     art. 32 LOPDGDD
     Agencia Española de Protección de Datos: resolución E/04230/2021 sobre los arts. 32 y
     33 del RGPD
     EIOPA: respuesta DORA237-3350 sobre la exclusión de intermediarios pymes
     Portal de firma electrónica del Gobierno de España: base legal eIDAS
     Legal Today: el valor de la firma electrónica como prueba en el proceso civil
     Reteno: botones de acción en notificaciones (tres en Android)
     App Store: Renu:Wise

No se ha podido abrir el texto consolidado del BOE de la Ley 50/1980; la numeración
exacta de los apartados del art. 22 debe confirmarse allí. Los artículos del RGPD se citan
por su numeración oficial y conviene confirmarlos en EUR-Lex.




                                                                                          Page 23 of 23
