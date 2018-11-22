function adquisicion_v2018_aux_v2(src, event)
    % IMPORTANTE %
    % Esta función NO puede ser modificada durante la medición
    % Defino variables que persisten entre llamados de la funcion 
    % Testear!
    persistent previousData
    persistent previousTime
    persistent lastRecordedEnd
    persistent lastPlaybackProtocol
    persistent isPlaybackTime
    persistent lastPlayback
    persistent isProtocolRunning
    persistent playbackNumber
    persistent isPlaybackRunning
    persistent playbackWav
    persistent playbackName
    persistent playbackSequence
    persistent recordNumber
    persistent triggerActivado
    persistent startTime
    
    % Creo carpetas
    base_folder = 'F:\Juan 2018\';
    log_filename = 'adq-log.txt';
    birdname = 'BVNaNa';
    
    % Hacer protocolos de playback?
    do_playback = true;
    do_random_saves = true;
    
    % Grabar solo sonido o los otros canales tambien?
    solo_sonido = false;
    % Trigger settings
    sound_threshold = 0.15;
    sound_integral = 500;
    
    nighttime_trigger_signal = 'vs';
    nighttime_threshold = 0.05;
    nighttime_integral = 500;
    
    random_save_every = 5*60;
    
    bird_folder = [base_folder, birdname, '\'];
    if isempty(dir(bird_folder))
        mkdir(bird_folder);
    end
    
    num_canales = length(src.Channels);
    channel_names = cell(num_canales, 1);
    for ncanal=1:num_canales
        channel_name = src.Channels(ncanal).Name;
        channel_names{ncanal} = channel_name;
    end
    % Trigger settings
    dt_integral = 1;    % Tiempo de integracion para trigger
    dt_trigger = 1;     % Cada cuanto llama al listener
    samples_trigger = floor(src.Rate*dt_trigger);
    
    if do_random_saves
        random_save_probability = dt_integral/random_save_every;
    else
        random_save_probability = 0;
    end
    
    % Settings de medicion
    t_medicion_dia = 15;    % Duracion de cada medicion diurna
    t_medicion_noche = 30;  % Duracion de cada medicion nocturna
    t_total = 60*60*24*3;       % Tiempo total de medicion
    daytime = [6 20];     % hour range of daytime
   
    % Playback settings
    % Donde estan los wavs de playback
    playback_folder = 'F:\Juan 2018\BVNaNa\Playbacks\13112018\';
    playback_start_time = 22;
    playback_end_time = 5;
    inter_protocol_delay = 60*20;  % Tiempo entre protocolos de playback
    intra_protocol_delay = 5;  % Tiempo entre playbacks dentro del protocolo
    playback_files = dir([playback_folder '\*.wav']); %file list of playback wavs
    % Repeticiones de cada playback por protocolo
    playback_repetition = 1;
    % number of seconds of silence before each playback
    playback_silence_delay = 3;
    pre_samples_playback = floor(src.Rate*playback_silence_delay);
    % number of seconds to recall for each playback including the silence
    % delay: playback files should last less than 
    % playback_record_time - playback_silence_delay
    playback_record_time = 20;
    samples_playback = floor(src.Rate*playback_record_time);
    
    t_buffer = max([t_medicion_dia, t_medicion_noche, ...
        playback_silence_delay+playback_record_time]);
    samples_buffer = floor(src.Rate*t_buffer);
    now_vec = clock;
    hour = now_vec(4);  % getting actual hour
    % Me fijo si es de dia o de noche
    isDay = 0;
    if hour >= daytime(1) && hour < daytime(2)
        isDay = 1;
    end
    % Determino que canal uso para triggerear
    % Pensar con mas canales
    if isDay || solo_sonido
        trigger_type = 'sound';
        trigger_channel = find(ismember(channel_names, trigger_type));
        value_threshold = sound_threshold;
        integral_threshold = sound_integral;
    else
        trigger_type = nighttime_trigger_signal;
        trigger_channel = find(ismember(channel_names, trigger_type));
        value_threshold = nighttime_threshold;
        integral_threshold = nighttime_integral;
    end
    % Me fijo si es momento de hacer playbacks
    isPlaybackTime = 0;
    if (hour >= playback_start_time || hour < playback_end_time) ...
            && do_playback
        isPlaybackTime = 1;
    end    
    % Obtengo fecha para crear carpeta
    time_vec = clock;
    year = num2str(time_vec(1));
    month = num2str(time_vec(2),'%02i');
    today  = num2str(time_vec(3),'%02i');
    yesterday = num2str(time_vec(3)-1,'%02i');
    hour_num = time_vec(4);
    if isDay
        date = {year, month, today, 'day'};
    elseif hour_num >= daytime(2)
        date = {year, month, today, 'night'};
    else
        date = {year, month, yesterday, 'night'};
    end
    strdate = strjoin(date, '-');
    date_folder = [bird_folder, strdate, '\'];
    if (~exist(date_folder,'dir'))    % Creando carpeta y log del dia
        mkdir(date_folder);
        log = fopen([date_folder '\' log_filename],'wt');
        fprintf(log, 'date\ttime\t');
        for ncanal=1:num_canales
            fprintf(log, '%s_fname\t', channel_names{ncanal});
            fprintf(log, '%s_max\t', channel_names{ncanal});
            fprintf(log, '%s_min\t', channel_names{ncanal});
        end
        fprintf(log, 'trigger\tintegral\tplayback_fname\n');
        fclose(log);
    end
    % Nuevos datos que se agregan al llamar al listener
    new_data = event.Data;
    new_time = event.TimeStamps;
    if src.ScansAcquired >= samples_trigger
        data = [previousData;new_data];
        time = [previousTime;new_time];
    end
    % Tiempo maximo de los datos que tengo.
    end_time = max(time);
    % Al principio espero hasta juntar los datos de una medicion al menos
    if src.ScansAcquired < samples_buffer
        if max(time) <= dt_integral
            src
            fprintf('ID ave: %s\n', birdname)
            if solo_sonido
                fprintf('Grabando SOLO SONIDO\n')
                fprintf('Sound trigger\n Umbral: %f ||| Integral: %f\n', ...
                    sound_threshold, sound_integral)
                fprintf('Se grabarán mediciones de %is\n', t_medicion_dia)
            else
                fprintf('Grabando:\n')
                fprintf('%s - ', channel_names{:})
                fprintf('\n---Sound trigger---\nUmbral: %f ||| Integral: %f\n', ...
                    sound_threshold, sound_integral)
                fprintf('\n---Trigger nocturno---\n%s', nighttime_trigger_signal)
                fprintf('\n%s trigger\n Umbral: %f ||| Integral: %f\n', ...
                    nighttime_trigger_signal, nighttime_threshold, nighttime_integral)
                fprintf('\nSe grabarán mediciones de:\nDía: %is\tNoche: %is\tPlayback: %is\n', ...
                    t_medicion_dia, t_medicion_noche, playback_silence_delay+playback_record_time)
                if ~do_playback
                    fprintf('No se reproducirán playbacks\n')
                else
                    fprintf('Playback protocol:\nInicio: %ihs\t Fin: %ihs\n', ...
                        playback_start_time, playback_end_time)
                    fprintf('Repeticiones: %i\t Intra-delay: %is\t Inter-delay: %is\n', ...
                        playback_repetition, intra_protocol_delay, inter_protocol_delay)
                    fprintf('Silencio previo: %is\t Tiempo por playback: %is\n', ...
                        playback_silence_delay, playback_record_time)
                    num_playback_files = length(playback_files);
                    file_durations = zeros(num_playback_files, 1);
                    for i=1:num_playback_files
                        file_info = audioinfo([playback_folder, playback_files(i).name]);
                        file_durations(i) = file_info.Duration();
                    end
                    [MM, II] = max(file_durations);
                    fprintf('Playback mas largo: %fs (%s)\n', ...
                        MM, playback_files(II).name)
                    fprintf('Se reproducirán los siguientes playbacks:\n')
                    fprintf('%s\n', playback_files.name)
                end
            end
            if random_save_probability > 0
                fprintf('Se grabarán mediciones al azar (sin trigger) cada ~%is\n', random_save_every)
            else
                fprintf('No se grabarán mediciones al azar\n')
            end
            fprintf('Buffering')
        else
            fprintf('.')
        end
        % Guardo datos para la proxima vuelta
        previousData = data;
        previousTime = time;
        lastRecordedEnd = 0;
        isPlaybackRunning = 0;
        isProtocolRunning = 0;
        lastPlayback = datevec(addtodate(now, -intra_protocol_delay, 'second'));
        lastPlaybackProtocol = datevec(addtodate(now, -inter_protocol_delay, 'second'));
        isPlaybackTime = 0;
        playbackNumber = 0;
        recordNumber = 0;
        triggerActivado = false;
    elseif time(end) > t_total
        % Si pase el tiempo total corto
        src.stop()
    else % Hago cosas
        if isPlaybackRunning    % Si esta pasando un playback
            if end_time-startTime > playback_record_time   % si medi el tiempo suficiente
                ref_time = addtodate(datenum(clock), -playback_record_time, 'second');
                fecha = datestr(ref_time,'yyyy_mm_dd');
                hora = datestr(ref_time,'HH.MM.SS');
                str_rectime = datestr(ref_time,'yyyy_mm_dd-HH.MM.SS');
                % Normalizo para guardar wav
                pb_data = data(end-(samples_playback+pre_samples_playback)+1:end,:);
                pb_time = time(end-(samples_playback+pre_samples_playback)+1:end);
                norm_data = bsxfun(@minus,pb_data,mean(pb_data));
                norm_data = bsxfun(@rdivide,norm_data,max(abs(norm_data)));
                trigger_type = 'playback';
                log = fopen([date_folder '\' log_filename],'at');
                fprintf(log,'%s\t%s\t', fecha, hora);
                max_integral = 0;

                fprintf('-- Datos --\n')
                fprintf('Carpeta: %s\nHora: %s\nIntegral = %f\n', ...
                    fecha,hora,max_integral);
                fprintf('Numero de grabacion: %i\n', ...
                    recordNumber);
                fprintf('Trigger: %s\nPlayback: %s\n-----------\n', ...
                    trigger_type,playbackWav);
                for ncanal=1:num_canales
                    channel_name = src.Channels(ncanal).Name;
                    channel_data = pb_data(:, ncanal);
                    figure(1)
                    subplot(num_canales, 1, ncanal)
                    plot(pb_time, channel_data)
                    title(channel_name);
                    xlim([min(pb_time) max(pb_time)])
                    figure(2)
                    h = subplot(num_canales, 1, ncanal);
                    [~,F,T,P]=spectrogram(channel_data,gausswin(round((15E-3)*src.Rate),2),...
                        round(0.97*(10E-3)*src.Rate),2^nextpow2((10E-3)*src.Rate),...
                        src.Rate,'yaxis');
                    imagesc(T,F/1000,10*log10(P/20));
                    set(gca,'YDir','normal');
                    set(h,'YLim',[0 8]);
                    title(channel_name);
                    max_channel = max(channel_data);
                    min_channel = min(channel_data);
                    name = [channel_name, '_', birdname, '_', str_rectime, '_', playbackName, '.wav'];
                    filename = [date_folder '\' name];
                    audiowrite(filename, norm_data(:,ncanal), floor(src.Rate));
                    % appending entry to log
                    fprintf(log,'%s\t%f\t%f\t', name, max_channel, min_channel);
                    fprintf('Max_%s = %f\tMin_%s = %f\n', channel_name, ...
                        max_channel, channel_name, min_channel);
                end
                fprintf(log, '%f\t%s\t%s\n', max_integral, trigger_type, playbackWav);
                fclose(log);
                fprintf('Trigger: %s\nPlayback: %s\n-----------\n', ...
                    trigger_type,playbackWav);
                isPlaybackRunning = false;
                lastPlayback = clock;
                fprintf('Playback finalizado\n')
            end
        elseif isProtocolRunning
            % Si esta corriendo un protocolo de playback, pero no un playback
            if etime(clock, lastPlayback) >= intra_protocol_delay
                playbackNumber = playbackNumber + 1;
                if playbackNumber <= length(playbackSequence)
                    playbackWav = playback_files(playbackSequence(playbackNumber)).name; %selecting file acording to previously determined random sequence
                    fprintf('Playback numero %i: %s\n', playbackNumber, playbackWav)
                    % Tiempo desde el que voy a empezar a guardar
                    startTime = end_time - playback_silence_delay;
                    playbackName = strtok(playbackWav, '_');  % id tipo file
                    [rep, fs] = audioread([playback_folder '\' playbackWav]); %loading wav
                    isPlaybackRunning = true;
                    fprintf('Pasando playback...\n')
                    soundsc(rep,fs,16,[-1 1]*max(abs(rep)));
                else
                    fprintf('Protocolo finalizado\n')
                    lastPlaybackProtocol = clock;
                    playbackNumber = 0;
                    isProtocolRunning = false;
                    lastRecordedEnd = time(end);
                end
            end
        elseif (isPlaybackTime && ...
                etime(clock, lastPlaybackProtocol) > inter_protocol_delay)
            % Si tengo que arrancar un protocolo genero un vector que da el
            % orden en que se van a reproducir los archivos de playback
            nn = 0;
            playbackSequence = [];
            while nn < playback_repetition
                playbackSequence = [playbackSequence, randperm(length(playback_files))];
                nn = nn + 1;
            end
            fprintf('Playback protocol started\n')
            isProtocolRunning = true;
        else
            % Chequeo si los ultimos datos van a disparar el trigger en el
            % futuro
            t_medicion_actual = t_medicion_dia;
            if ~isDay
                t_medicion_actual = t_medicion_noche;
            end
            samples_medicion_actual = floor(src.Rate*t_medicion_actual);
            abs_window_sum = movsum(abs(data(:, trigger_channel)), samples_trigger);
            if isDay && ((any(new_data(:, trigger_channel)) > value_threshold)) ...
                && any(abs_window_sum(end-samples_trigger:end)) > integral_threshold ...
                && ~triggerActivado
                fprintf('>> Trigger activado <<\n')
                fprintf('Midiendo (%i segundos)...\n', t_medicion_dia)
                triggerActivado = true;
            end
            % Defino intervalo de interes para determinar si guardo
            left_lim = floor(src.Rate*1);   % 1 segundo de buffer previo
            right_lim = left_lim + samples_trigger;
            max_integral = max(abs_window_sum(end-samples_medicion_actual+left_lim:end-samples_medicion_actual+right_lim));
            trigger_data = data(end-samples_medicion_actual+left_lim:end-samples_medicion_actual+right_lim, trigger_channel);
            random_save = rand(1) < random_save_probability;
            trigger_condition = (any(trigger_data > value_threshold) ...
                    && max_integral > integral_threshold ...
                    && time(end)-lastRecordedEnd >= t_medicion_dia);
            if trigger_condition || random_save
                sv_data = data(end-samples_medicion_actual+1:end, :);
                sv_time = time(end-samples_medicion_actual+1:end, :);
                fprintf('Guardando\n')
                triggerActivado = false;
                recordNumber = recordNumber + 1;
                
                ref_time = addtodate(datenum(clock), -t_medicion_dia, 'second');
                fecha = datestr(ref_time,'yyyy_mm_dd');
                hora = datestr(ref_time,'HH.MM.SS');
                str_rectime = datestr(ref_time,'yyyy_mm_dd-HH.MM.SS');
                
                % Normalizo para guardar wav
                norm_data = bsxfun(@minus,sv_data,mean(sv_data));
                norm_data = bsxfun(@rdivide,norm_data,max(abs(norm_data)));
                log = fopen([date_folder '\' log_filename],'at');
                fprintf(log,'%s\t%s\t', fecha, hora);
                playbackWav = 'NA';
                if random_save
                    trigger_type = 'random';
                    fprintf('Random save!\n')
                elseif isDay || solo_sonido
                    trigger_type = 'sound';
                else
                    trigger_type = 'vs';
                end
                fprintf('-- Datos --\n')
                fprintf('Carpeta: %s\nHora: %s\nIntegral = %f\n', ...
                    date_folder,hora,max_integral);
                fprintf('Numero de grabacion: %i\n', ...
                    recordNumber);
                fprintf('Trigger: %s\nPlayback: %s\n-----------\n', ...
                    trigger_type,playbackWav);
                for ncanal=1:num_canales
                    channel_name = src.Channels(ncanal).Name;
                    channel_data = sv_data(:,ncanal);
                    figure(1)
                    subplot(num_canales, 1, ncanal)
                    plot(sv_time, channel_data)
                    title(channel_name);
                    xlim([min(sv_time) max(sv_time)])
                    figure(2)
                    h = subplot(num_canales, 1, ncanal);
                    [~,F,T,P]=spectrogram(channel_data,gausswin(round((15E-3)*src.Rate),2),...
                        round(0.97*(10E-3)*src.Rate),2^nextpow2((10E-3)*src.Rate),...
                        src.Rate,'yaxis');
                    imagesc(T,F/1000,10*log10(P/20));
                    set(gca,'YDir','normal');
                    set(h,'YLim',[0 8]);
                    title(channel_name);
                    max_channel = max(channel_data);
                    min_channel = min(channel_data);
                    name = [channel_name, '_', birdname, '_', str_rectime, '.wav'];
                    filename = [date_folder '\' name];
                    audiowrite(filename, norm_data(:,ncanal), floor(src.Rate));
                    % appending entry to log
                    fprintf(log,'%s\t%f\t%f\t', name, max_channel, min_channel);
                    fprintf('Max_%s = %f\tMin_%s = %f\n', channel_name, ...
                        max_channel, channel_name, min_channel);
                end
                fprintf(log, '%f\t%s\t%s\n', max_integral, trigger_type, playbackWav);
                fclose(log);
                lastRecordedEnd = sv_time(end);
            end
        end
        previousData = data(end-samples_buffer+1:end,:);
        previousTime = time(end-samples_buffer+1:end);
    end
end
