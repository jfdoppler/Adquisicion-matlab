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
% Puertos fisicos output
ao_channel = 0;
% Puerto fisico input (salida amplificador)
ai_channel = 3;
% Puerto fisico input conectado a output (mido para asegurar sincronia)
ao_meas_channel = 2;
% Agrego canales y seteo rate
input_ch = addAnalogInputChannel(s, 'Dev1', ai_channel, 'Voltage');
output_meas_ch = addAnalogInputChannel(s, 'Dev1', ao_meas_channel, 'Voltage');
output_ch = addAnalogOutputChannel(s, 'Dev1', ao_channel, 'Voltage');
s.Rate = 44150;
disp('Listo')

%% Medicion a una frecuencia
clc
close all
freq = 100;
amplitud = 1;
n_periodos = 10;
duracion = n_periodos/freq;
output_data = amplitud*sin(linspace(0,2*pi*n_periodos,s.Rate*duracion)');
% plot(output_data)
queueOutputData(s, output_data)
[data, time] = s.startForeground();
signal = data(:,1);
signal_peaks = findpeaks(signal);
output_meas_signal = data(:,2);
subplot(3,1,1)
plot(time, output_data)
subplot(3,1,2)
plot(time, output_meas_signal)
subplot(3,1,3)
plot(time, signal)
set(gcf,'Position',[100 100 1000 500])

%% Barrido en frecuencia
clc
close all
min_freq = 100;
max_freq = 10000;
num_freqs = 10;
amplitud = 0.5;
frecuencias = linspace(min_freq, max_freq, num_freqs);
signal_amp = zeros(1, length(frecuencias));
signal_amp_error = zeros(1, length(frecuencias));
output_amp = zeros(1, length(frecuencias));
output_amp_error = zeros(1, length(frecuencias));
time_delay = zeros(1, length(frecuencias));
for i=1:numel(frecuencias)
    freq = frecuencias(i);
    n_periodos = 10;
    duracion = n_periodos/freq;
    output_data = amplitud*sin(linspace(0,2*pi*n_periodos,s.Rate*duracion)');
    queueOutputData(s, output_data)
    [data, time] = s.startForeground();
    % Señal amplificada
    signal = data(:,1);
    signal_peaks = findpeaks(signal, 'MinPeakProminence', max(signal)/10,...
        'MinPeakDistance', length(signal)/(2*n_periodos));
    signal_amp(i) = mean(signal_peaks);
    signal_amp_error(i) = std(signal_peaks);
    % Señal de entrada
    output_signal = data(:,2);
    output_signal_peaks = findpeaks(output_signal, 'MinPeakProminence',...
        max(output_signal)/10, 'MinPeakDistance', length(output_signal)/(2*n_periodos));
    output_amp(i) = mean(output_signal_peaks);
    output_amp_error(i) = std(output_signal_peaks);
    time_delay(i) = finddelay(output_signal, signal, floor(s.Rate/(2*freq)))/s.Rate;
end
%% Grafico
subplot(4,1,1)
errorbar(frecuencias, signal_amp, signal_amp_error)
ylabel('Amplitud amplificada')
subplot(4,1,2)
errorbar(frecuencias, output_amp, output_amp_error)
ylabel('Amplitud entrada')
subplot(4,1,3)
gain = output_amp./signal_amp;
gain_error = sqrt(gain.*(output_amp_error.^2./output_amp+signal_amp_error.^2./signal_amp));
errorbar(frecuencias, gain, gain_error)
xlabel('Frecuencia (Hz)')
ylabel('Ganancia')
subplot(4,1,4)
plot(frecuencias, time_delay)
ylabel('Time delay (s)')
amp_phase = time_delay*2*pi.*frecuencias;
yyaxis right
plot(frecuencias, amp_phase)
ylabel('Fase (rad)')
set(gcf,'Position',[100 50 1000 600])
