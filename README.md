# Adquisicion-matlab
Codigos de adquisicion para matlab

Estan subidas las versiones 32 bits (modo legacy, obsoletas) y las versiones para 64 bits (session-based, activas)


# adquisicion_v2018_base.m

Implementa adquisicion en matlab usando session based interface para placas de adquisicion de NI.

En primer lugar configura la placa: agrega los canales correspondientes,
setea rangos de adquisicion y rate. Luego (segunda celda) corre una
adquisicion corta para ayudar a setear los valores de triggereo. Grafica
las dos seÃales adquiridas y las integrales de las mismas en ventanas de
1 segundo, ademas de los espectrogramas de cada uno.
Elegido el canal que se va a usar para triggerear se puede usar este
grafico para ver el rango de la seÃal correspondiente en un intervalo
sin actividad y el valor de la integral tipico en el mismo. Estos
valores NO se ingresan en este archivo, sino en el _aux.

Por ultimo (tercera celda) se corre una adquisicion en background
(medicion) en forma continua (no bloquea la consola). En esta celda se
debe configurar cada cuanto tiempo se llama al LISTENER. El listener es
la funcion del archivo _aux en la que se realiza todo el
analisis/guardado de las seÃales, el cual se debe configurar antes de
largar cada medicion. Alli se elegira que canales se adquieren, en que
condiciones, si se hacen playbacks, donde se guardaran los archivos,
etc.

Para detener la adquisicion se deben correr en forma consecutiva los
comandos:
s.stop() -> detiene la adquisicion
delete(lh) -> borra el puntero al listener.

La modificacion del listener solo se puede realizar tras correr estos
comandos. Si no se detiene la medicion, al llamar al listener dara error
ya que lo encontrara cambiado. Si no se lo borra, al comenzar una nueva
adquisicion seguira apuntando al listener viejo. Ante la duda hacer un
"daqreset" y configurar la placa nuevamente.

# adquisicion_v2018_aux.m

Este archivo es el que contiene a la funcion del listener.

El archivo base llama a esta funcion cuando tiene una cantidad de
samples definida y ejecuta el codigo que se encuentra en la funcion.
Como se encuentra dentro de una funcion, para seguir variables y guardar
datos es necesario usar variables persistentes! Estas son definidas al
principio del codigo.

Aunque puede parecer ineficiente, para mantener todas las
configuraciones de adquisicion en un mismo archivo (este), la creacion
de carpetas y demas se encuentra al principio del listener. En caso de
que eventualmente hubiera problemas de timing se pude incrementar el
tiempo entre llamados (ahora es 1 segundo).

En este archivo es IMPORTANTE configurar adecuadamente las siguientes
variables (c/ ejemplo de formato):

base_folder = 'C:\Users\LSD\Desktop\Juan 2018\';

log_filename = 'adq-log.txt';

birdname = 'CeRo';

do_playback = true;

do_random_saves = true;

solo_sonido = false;

sound_channel = 1;

vs_channel = 2;

dt_integral = 1;

dt_trigger = 1;

random_save_every = 30*60;

t_medicion_dia = 60;

t_medicion_noche = 20;

t_total = 60*60*24*3;

daytime = [6 20];

playback_folder = 'C:\Users\LSD\Desktop\Juan 2018\CeRo\Playbacks\31082018\';

playback_start_time = 21;

playback_end_time = 5;

inter_protocol_delay = 60*15;

intra_protocol_delay = 5;

playback_repetition = 2;

playback_silence_delay = 3;

playback_record_time = 15;

value_threshold = 0.05;

integral_threshold = 80

Los nombres son en general claros. Las ultimas dos (trigger related) se
deteminan usando la segunda celda del archivo base y se deben configurar
para los casos de trigger con musculo y con sonido.

El codigo opera de forma secuencial (? no se que otra palabra usar), con
condiciones anidadas. Los estados son, en el orden en el que se
chequean: esta pasando un playback (y veo si termino), esta pasando un
protocolo de playback (y veo si tengo que pasar un playback), normal. En
caso de normal, se verifica si se cumplen las condiciones de trigger
para guardar.

Para agregar: playbacks diurno

# adquisicion_v2018_base/aux_todas.m

Hacen lo mismo que los otros codigos pero adquieren de 5 canales: sonido, tension, presion, hall, ecg.
De noche triggerea con tension (se puede cambiar a mano con que canal triggerea: mejorar)
