% Adquisicion para Matlab 64 bits Version Juan Junio 2018
% Basada en:
% AVIMAT Version Alan Julio 2016
% AVIMAT Gogui versión Octubre 2014
% AVIMAT Goldin versión Septiembre 2012
% AVIMAT Alliende Arneodo (y el help de Matlab) versión 10-06-2010

clc
clear all
close all
%% Configuracion basica de la placa
disp('Configurando...')
daqreset
s = daq.createSession('ni');
% Puertos fisicos donde estan conectados los inputs
sound_aichannel = 0;
vs_aichannel = 1;
% Cuantos canales puedo medir sin perder frecuencia de adquisicion?
pressure_aichannel = 2;
hall_aichannel = 3;
ecg_aichannel = 4;
% Agrego canales y seteo rate
s_ch = addAnalogInputChannel(s, 'Dev1', sound_aichannel, 'Voltage');
vs_ch = addAnalogInputChannel(s, 'Dev1', vs_aichannel, 'Voltage');
vs_ch.Range = [-1, 1];
pr_ch = addAnalogInputChannel(s, 'Dev1', pressure_aichannel, 'Voltage');
hall_ch = addAnalogInputChannel(s, 'Dev1', hall_aichannel, 'Voltage');
ecg_ch = addAnalogInputChannel(s, 'Dev1', ecg_aichannel, 'Voltage');
s.Rate = 44150;
% De los canales conectados cual es cada uno. Cuidado, importa el orden
% P. ej si se agregaron los canales 0, 2, 1 (en ese orden)
% x_channel = 1 == x esta conectada a la entrada 0 (ai0)
% y_channel = 3 == y esta conectada a la entrada 1 (ai1)
% Puedo preguntarle esto al objeto s?
sound_channel = 1; 
vs_channel = 2;
pr_channel = 3;
hall_channel = 4;
ecg_channel = 5;
disp('Listo')
%% Setear trigger
clc
close all
s.IsContinuous = false;
s.DurationInSeconds = 5;
% Que canal voy a mirar para usar luego como trigger
dt_integral = 1;    % Tiempo de integracion
samples_integral = floor(s.Rate*dt_integral);
% Empiezo la medicion
[data, time] = s.startForeground();
sound = data(:, sound_channel);
vs = data(:, vs_channel);
pressure = data(:, pr_channel);
hall = data(:, hall_channel);
ecg = data(:, ecg_channel);

subplot(6, 1, 1)
plot(time, sound)
h = subplot(6, 1, 2);
[~, F, T, P] = spectrogram(sound, gausswin(round((15E-3)*s.Rate), 2),...
    round(0.97*(10E-3)*s.Rate), 2^nextpow2((10E-3)*s.Rate),...
    s.Rate, 'yaxis');
imagesc(T, F/1000, 10*log10(P/20));
set(gca, 'YDir', 'normal');
set(h, 'YLim', [0 8]);

subplot(6, 1, 3)
plot(time, movsum(abs(sound), samples_integral))

subplot(6, 1, 4)
plot(time, vs)

h = subplot(6, 1, 5);
[~, F, T, P] = spectrogram(vs, gausswin(round((15E-3)*s.Rate), 2),...
    round(0.97*(10E-3)*s.Rate), 2^nextpow2((10E-3)*s.Rate),...
    s.Rate, 'yaxis');
imagesc(T, F/1000, 10*log10(P/20));
set(gca, 'YDir', 'normal');
set(h, 'YLim', [0 8]);

subplot(6, 1, 6)
plot(time, movsum(abs(vs), samples_integral))
set(gcf, 'Position', [100 50 1000 600])

%% Medicion
clc
close all
% Creo un listener al que va a llamar (y ejecutar) la funcion que le digo
% cuando tenga datos disponibles
lh = addlistener(s, 'DataAvailable', @adquisicion_v2018_aux_todas);
% La función está en un .m aparte. No puede ser modificada durante la 
% medición

% Adquiero en forma continua. La condicion de trigger, guardar y terminar
% medicion se incorporan dentro del listener
s.IsContinuous = true;
% Defino cada cuanto tiempo llamo al listener
% Esta variable debe estar definida igual en la funcion del listener
dt_trigger = 1;
s.NotifyWhenDataAvailableExceeds = floor(s.Rate*dt_trigger);
% Empiezo la medicion
s.startBackground();
% PARA DETENER LA MEDICION %
% s.stop()
% delete(lh)