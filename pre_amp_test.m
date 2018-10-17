% Adquisicion para Matlab 64 bits Version Juan Junio 2018
% Basada en:
% AVIMAT Version Alan Julio 2016
% AVIMAT Gogui versión Octubre 2014
% AVIMAT Goldin versión Septiembre 2012
% AVIMAT Alliende Arneodo (y el help de Matlab) versión 10-06-2010
% Prueba de funcionamiento de pre amplificador

clc
clear all
close all
%% Configuracion basica de la placa
disp('Configurando...')
daqreset
s = daq.createSession('ni');
% Puertos fisicos donde estan conectados los inputs
ai_channel = 3;
ao_channel = 0;
ao_meas_channel = 2;
% Agrego canales y seteo rate
input_ch = addAnalogInputChannel(s, 'Dev1', ai_channel, 'Voltage');
output_meas_ch = addAnalogInputChannel(s, 'Dev1', ao_meas_channel, 'Voltage');
output_ch = addAnalogOutputChannel(s, 'Dev1', ao_channel, 'Voltage');
s.Rate = 44150;
disp('Listo')
%%
clc
close all
min_freq = 100;
max_freq = 10000;
num_freqs = 10;
amplitud = 0.025;
frecuencias = linspace(min_freq, max_freq, num_freqs);
input_amp = zeros(1, length(frecuencias));
output_amp = zeros(1, length(frecuencias));
for i=1:numel(frecuencias)
    freq = frecuencias(i);
    duracion = 10./freq;
    output_data = amplitud*sin(linspace(0,2*pi*freq,s.Rate*duracion)');
    queueOutputData(s, output_data)
    [data, time] = s.startForeground();
    input_amp(i) = range(data(:,1));
    output_amp(i) = range(data(:,2));
end
subplot(3,1,1)
plot(frecuencias, input_amp)
subplot(3,1,2)
plot(frecuencias, output_amp)
subplot(3,1,3)
plot(frecuencias, output_amp./input_amp)
set(gcf,'Position',[100 100 1000 1000])

