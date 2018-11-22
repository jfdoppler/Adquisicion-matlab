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
vs_aichannel = 2;
medir_vs = true;
pressure_aichannel = 2;
medir_pr = false;
hall_aichannel = 3;
medir_hall = false;
ecg_aichannel = 4;
medir_ecg = false;
% Agrego canales y seteo rate
[s_ch, sound_channel] = addAnalogInputChannel(s, 'Dev1', sound_aichannel, 'Voltage');
s_ch.Name = 'sound';
if medir_vs
    [vs_ch, vs_channel] = addAnalogInputChannel(s, 'Dev1', vs_aichannel, 'Voltage');
%     vs_ch.Range = [-1, 1];
    vs_ch.Name = 'vs';
end
if medir_pr
    [pr_ch, pr_channel] = addAnalogInputChannel(s, 'Dev1', pressure_aichannel, 'Voltage');
    pr_ch.Name = 'pressure';
end
if medir_hall
    [hall_ch, hall_channel] = addAnalogInputChannel(s, 'Dev1', hall_aichannel, 'Voltage');
    hall_ch.Name = 'hall';
end
if medir_ecg
    [ecg_ch, ecg_channel] = addAnalogInputChannel(s, 'Dev1', ecg_aichannel, 'Voltage');
    ecg_ch.Name = 'ecg';
end
s.Rate = 44150;
disp('Listo')
%% Setear trigger
clc
close all
s.IsContinuous = false;
s.DurationInSeconds = 3;
save_test = true; % Agregar para guardar medicion de calibracion
% Que canal voy a mirar para usar luego como trigger
dt_integral = 1;    % Tiempo de integracion
samples_integral = floor(s.Rate*dt_integral);
% Empiezo la medicion
[data, time] = s.startForeground();
num_canales = length(s.Channels);
channel_names = cell(num_canales, 1);
for ncanal=1:num_canales
    figure(1)
    suptitle('Señal')
    channel_name = s.Channels(ncanal).Name;
    channel_names{ncanal} = channel_name;
    subplot(num_canales, 1, ncanal)
    plot(time, data(:, ncanal))
    title(channel_name)
    figure(2)
    suptitle('Integral')
    subplot(num_canales, 1, ncanal)
    plot(time, movsum(abs(data(:, ncanal)), samples_integral))
    title(channel_name)
    figure(3)
    suptitle('Espectro')
    h = subplot(num_canales, 1, ncanal);
    [~, F, T, P] = spectrogram(data(:, ncanal), gausswin(round((15E-3)*s.Rate), 2),...
        round(0.97*(10E-3)*s.Rate), 2^nextpow2((10E-3)*s.Rate),...
        s.Rate, 'yaxis');
    imagesc(T, F/1000, 10*log10(P/20));
    set(gca, 'YDir', 'normal');
    set(h, 'YLim', [0 8]);
    title(channel_name)
end

%% Medicion
clc
close all
% Creo un listener al que va a llamar (y ejecutar) la funcion que le digo
% cuando tenga datos disponibles
lh = addlistener(s, 'DataAvailable', @adquisicion_v2018_aux_v2);
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