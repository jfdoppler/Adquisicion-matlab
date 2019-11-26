% Codigo para testear adquisición
clc
clear all
close all
%% Configuracion basica de la placa
disp('Configurando...')
daqreset
s = daq.createSession('ni');
% Puertos fisicos donde estan conectados los inputs
ai_channels = [2, 3];
ai_channel_names = ['mic1-ch1'; 'mic2-ch2'];
ch_info = [];
channel_num = [];
for i=1:length(ai_channels)
    [info_aux, num_aux] = addAnalogInputChannel(s, 'Dev1', ai_channels(i), 'Voltage');
    info_aux.Name = ai_channel_names(i, :);
    ch_info = [ch_info, info_aux];
    channel_num = [channel_num, num_aux];
end
s.Rate = 44150;
disp('Listo')
%% Medicion
clc
close all
s.IsContinuous = false;
s.DurationInSeconds = 5;
save_test = true; % Agregar para guardar medicion de calibracion

% Empiezo la medicion
[rep, fs] = audioread('C:\Adquisicion-matlab\test_sound.wav'); %loading wav
soundsc(rep, fs, 16, [-1 1]*max(abs(rep)));
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
    suptitle('Espectro')
    h = subplot(num_canales, 1, ncanal);
    [~, F, T, P] = spectrogram(data(:, ncanal), gausswin(round((15E-3)*s.Rate), 2),...
        round(0.97*(10E-3)*s.Rate), 2^nextpow2((10E-3)*s.Rate),...
        s.Rate, 'yaxis');
    imagesc(T, F/1000, 10*log10(P/20));
    set(gca, 'YDir', 'normal');
    set(h, 'YLim', [0 5]);
    title(channel_name)
end