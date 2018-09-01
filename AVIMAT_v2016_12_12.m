%GRABO SOLO SONIDO y vS
% AVIMAT Version Alan Julio 2016
% AVIMAT Gogui versión Octubre 2014
% AVIMAT Goldin versión Septiembre 2012
% AVIMAT Alliende Arneodo (y el help de Matlab) versión 10-06-2010


%% Initialization
close all
clear all
daqreset
fin=2;
%DE DONDE GRABAR Y TODO ESO
%carpeta base (sin la / al final): es donde va a generar carpetas con la fecha

%% Defining constants
carpeta_base='C:\Users\usuario\Desktop\Juan 2018\canto';
log_filename='AVIMAT-log.txt';
nombreave='cG03_NF'; %identificación del pájaro a grabar
save_vs=1; %1 to save the vS channel, 0 don't save
playback=0; %should the script do a nighttime playback protocol
playback_folder='';
playback_time=[1 4]; %hour range in which to do playbak protocol
playback_files=dir([playback_folder '\*.wav']); %file list of playback wavs
playback_inter_prot_delay_lambda=10*60; %mean value of seconds of delay between consecutive protocols
playback_record_time=15; %number of seconds to recall for each playback
playback_silence_delay_mu=3; %mean number of seconds of silence before the actual playback starts
playback_silence_delay_sigma=0; %dispersion around mean
random_sampling_prob=0.01; %probability of saving a random acquisition (used for bg estimation)

%trigger con sonido
tiempo_medir=60*60*24*60; %segundos totales que se va a medir
daytime=[6 20]; %hour range of daytime (revisar que timer este en hora con la PC) 
tiempo_file=60; %segundos de medida por cada trigger
vs_ch=2; %Analog input channel of vS signal
vs_InputRange=[-1,1]; %Voltage range of vS channel
vs_trigger=0.05; %triger voltage value for vs channel
vs_integral_threshold=300; %threshold of integrated abs value in a tiempo ventana
vs_saturation=1.1*vs_InputRange(2); %saturation level for vs channel
s_ch=2; %Analog input channel of sound signal
s_InputRange=[-1,1]; %Voltage range of sound channel
s_trigger=0.15; %triger voltage value for sound channel
s_integral_threshold= 700; %threshold of integrated abs value in a tiempo ventana

tiempo_ventana=1; %tiempo en segundos de la ventana en la que se fija si hay canto o no
SampleRate= 44150;  % en Samples/sec (S/s);
SamplesVentana=ceil(SampleRate*tiempo_ventana); %el número de muestras por ventana
t_start=clock; %da Current date and time as date vector
seguir=1;
n=1;
SamplesPerTrigger = ceil(tiempo_file * SampleRate);   % number of total Samples

%initializing playback auxiliary variables
playback_last=clock;
playback_delay=0;
playback_prot_seq=randperm(length(playback_files));
playback_prot_counter=1;

%% Main Loop
%En general de aqui para abajo no es necesario modificaciones
while(seguir) % Starting main loop 
   try %por si falla algo no se cuelga el script y sigue grabando
      now_vec=clock; hour=now_vec(4); %getting actual hour
      now_vec(1)=now_vec(1)+1; %fecha atrasada (licencia ML)
      isDay=0; if hour>=daytime(1) && hour<daytime(2), isDay=1; end

      %% Initializing folders and log files
      carpeta=[carpeta_base,'\',nombreave,'\wavs']; 
      if isDay %daytime
        date_str=[num2str(now_vec(1),'%02i'),'-',num2str(now_vec(2),'%02i'),'-',num2str(now_vec(3),'%02i')];
        carpeta=[carpeta,'\',date_str,'-day'];
      else %nightime
        if hour >= daytime(2) %today
            date_str=[num2str(now_vec(1),'%02i'),'-',num2str(now_vec(2),'%02i'),'-',num2str(now_vec(3),'%02i')];
            carpeta=[carpeta,'\',date_str,'-night'];
        else %yesterday
            yesterday=datevec(addtodate(datenum(now_vec),-1,'day'));
            date_str=[num2str(yesterday(1),'%02i'),'-',num2str(yesterday(2),'%02i'),'-',num2str(yesterday(3),'%02i')];
            carpeta=[carpeta,'\',date_str,'-night'];
        end
      end
           
      if (~exist(carpeta,'dir')) %creating folder if it does not exist
           mkdir(carpeta) %creating folder
           log=fopen([carpeta '\' log_filename],'wt'); %creating log file in folder
           fprintf(log,'s_fname\tvS_fname\tdate\ttime\ts_max\ts_min\tvS_max\tvS_min\ttrigger\tplayback_fname\tsilence_delay\tdesc\n'); %creating header
           fclose(log);   
      end 
            
      %% Setting analog input  
      AI = analoginput('nidaq','Dev1');    % set the device
      ch = addchannel(AI, [vs_ch s_ch], {'vs','sound'});      % set two channels  1 and 2 on the board
      AI.Channel(vs_ch).InputRange=vs_InputRange; %setting input range of the channels
      AI.Channel(s_ch).InputRange=s_InputRange;
      set(AI, 'SampleRate',SampleRate) 
      set(AI, 'SamplesPerTrigger', SamplesPerTrigger)
      set(AI, 'TriggerType', 'software'); % sets type of trigger
      set(AI, 'TriggerRepeat', 0);        % number of triggers 0 just once 
      set(AI, 'TriggerCondition', 'rising'); % 
      if isDay || ~save_vs %triggering by sound during daytime or if there is no vS
        set(AI, 'TriggerChannel', ch(2)); %setting sound as trigger channel
        set(AI, 'TriggerConditionValue',s_trigger);  %  level of trigger
        umbralventana = s_integral_threshold;
        integral_channel=s_ch;
      else
        set(AI, 'TriggerChannel', ch(1)); %setting vs as trigger channel
        set(AI, 'TriggerConditionValue',vs_trigger);  %  level of trigger
        umbralventana = vs_integral_threshold;
        integral_channel=vs_ch;
      end
      set(AI, 'TriggerDelay', -1); % time recording before the trigger set(in, 'TriggerDelayUnits', 'seconds');
      set(AI, 'TimeOut', tiempo_medir+1); % %espera como mucho una hora. esto es para que no se quede colgada y haga los otros checks

      %% Playback
      is_playback=0; 
      playback_wav_current='NA';
      playback_type='';
      desc='';
      playback_silence_delay=0;
      if playback && isInIntervals(hour,playback_time) %if in playback conditions 
        if etime(clock,playback_last)>playback_delay %if enough time has passed from last playback
          %re-setting triger to zero (makes sure registers are saved)
          set(AI, 'SamplesPerTrigger', ceil(playback_record_time*SampleRate));
          set(AI, 'TriggerConditionValue',0);  %  level of trigger
          set(AI, 'TriggerDelay', 0); % time recording before the trigger set(in, 'TriggerDelayUnits', 'seconds');
          umbralventana = 0;

          %preparing sound
          playback_wav_current=playback_files(playback_prot_seq(playback_prot_counter)).name; %selecting file acording to previously determined random sequence
          playback_type=strtok(playback_wav_current,'_');
          [rep fs] = wavread([playback_folder '\' playback_wav_current]); %loading wav  
          %selecting random playback silence delay
          playback_silence_delay = normrnd(playback_silence_delay_mu,playback_silence_delay_sigma);
          playback_silence_delay = max(1.5,playback_silence_delay);
          rep = [zeros(round(playback_silence_delay*fs),1);rep]; %adding playback_silence seconds of delay before playing
          playback_delay=0; %setting next delay (0 for freerun)
          playback_last=clock; %resetting last playback time  
          is_playback=1;
          %desc=['Vol ' num2str(round(20*log10(1/2^playback_volume_attenuation_factor))) ' dB'];
   
          %playing sound
          soundsc(rep,fs,16,[-1 1]*max(abs(rep))); 
          disp(['Playback ' playback_wav_current ' ' num2str(playback_prot_counter) '/' num2str(length(playback_files)) ' silence_delay ' num2str(playback_silence_delay) ' ' desc]);
          playback_prot_counter = playback_prot_counter + 1;
          
          %setting up next protocol if necessary
          if playback_prot_counter > length(playback_files) %if last file in protocol
            playback_prot_counter=1;
            playback_delay=poissrnd(playback_inter_prot_delay_lambda); %setting next delay
            playback_prot_seq=randperm(length(playback_files));
            %playback_volume_attenuation_factor=randi(7)-1;
            disp(['Waiting ' num2str(playback_delay) ' seconds to next protocol']);
          end
        end
      end

      %% starts scanning for event
      start(AI);  %starts data adquisiton
      kk=0;
      cc=0;
      S_print=0;
      while AI.SamplesAcquired < AI.SamplesPerTrigger
            while AI.SamplesAcquired < SamplesVentana
                pause((SamplesVentana-AI.SamplesAcquired)/SampleRate);
            end
            data = peekdata(AI,SamplesVentana);
            %calculo la integral considerando unicamente los puntos en los que
            %vS no satura
            S=sum(abs(data(:,integral_channel))); 
            is_vs_saturated=(sum(abs(data(:,vs_ch))>vs_saturation)>=1); %cheking that vS is not saturated
            if (S>umbralventana && ~is_vs_saturated)% && ~is_vs_saturated) % Si la intregral es mayor que el umbral
                if ~kk, fprintf(' *** S=%d ***',round(S)); end
                fin=AI.SamplesAvailable;
                kk=1;% solo graba hasta las SamplesAvailable            
            elseif (S<umbralventana) && (kk==1) && (cc==0)
                fin=AI.SamplesAvailable;
                cc=1;
            elseif S_print==0
                fprintf(' S=%d vs_sat=%i |',round(S),is_vs_saturated);
                S_print=1;
            end
      end
      [channels time] = getdata(AI);
      stop(AI);

      %% Cheking if acquired data is worth saving
      random_save = rand < random_sampling_prob;
      if kk || random_save %if supra-threshold
         %%para dar nombre a los archivos 
         cuando=fix(clock);
         fecha=[num2str(cuando(1),'%02i'),'-',num2str(cuando(2),'%02i'),'-',num2str(cuando(3),'%02i')];
         hora=[num2str(cuando(4),'%02i') '.' num2str(cuando(5),'%02i') '.' num2str(cuando(6),'%02i')];

         if fin>length(time) %cheking ´fin´ and length of the vectors are ok
            errorLog=fopen([carpeta '\Error-log.txt'],'at'); %creating error log file in folder
            fprintf(errorLog,'Error on %s %s (n=%i) fin=%i and length(time)=%i [corrected]',...
                fecha,hora,n,fin,length(time)); %creating header
            fclose(errorLog); 
            fin=length(time);
         end  
         sonido = channels(1:fin,2); %sound is the second channel added
         vs = channels(1:fin,1); %vs is the first channel added
         time=time(1:fin);

         name_s=[nombreave,'_',fecha,'_',hora,'_s_',num2str(int2str(n),'%03i')];
         if is_playback, name_s=[name_s '_' playback_type]; end
         name_s=[name_s '.wav'];
         filename_s=[carpeta '\' name_s]; %genera el nombre del archivo de sonido
         max_s=max(sonido);
         min_s=min(sonido);
         if save_vs
             name_vs=[nombreave,'_',fecha,'_',hora,'_vs_',int2str(n)];
             if is_playback, name_vs=[name_vs '_' playback_type]; end
             name_vs=[name_vs '.wav'];
             filename_vs=[carpeta '\' name_vs]; %genera el nombre del archivo de vS
             max_vs=max(vs);
             min_vs=min(vs);
         else
             name_vs='NA';
             filename_vs='NA'; %genera el nombre del archivo de vS
             max_vs=0;
             min_vs=0;
         end

         %% appending entry to to log
         if isDay
            trigger_type='sound';
         else
            trigger_type='vs';
         end
         if random_save && ~kk, trigger_type='random'; end
         if is_playback, trigger_type='playback'; end
         log=fopen([carpeta '\' log_filename],'at'); %creating log file in folder
          fprintf(log,'%s\t%s\t%s\t%s\t%f\t%f\t%f\t%f\t%s\t%s\t%f\t%s\n', ...
            name_s,name_vs,fecha,hora,max_s,min_s,max_vs,min_vs,trigger_type,playback_wav_current,playback_silence_delay,desc); %creating header
         fclose(log); 

         %% saving normalizaed channels
         norm_s=1.998*(sonido-(max_s+min_s)/2.)/(max_s-min_s);
         wavwrite(norm_s,SampleRate,filename_s); % saves as .wav files
         if save_vs
            norm_vs=1.998*(vs-(max_vs+min_vs)/2.)/(max_vs-min_vs);
            wavwrite(norm_vs,SampleRate,filename_vs); %normalized
         end

         close
         figure(n)
         subplot(211),plot(time,sonido)
         subplot(212),plot(time,vs)
         % axis([-1 tiempo_file-1 -4 4])
         drawnow
         fprintf('\n SAVING FILE %i \n',n);
         n=n+1;
      end

      if(etime(clock,t_start)<=tiempo_medir)
         seguir=1;
      else
         seguir=0;
      end
      
   catch exception
      errorLog=fopen([carpeta '\Error-log.txt'],'at'); %creating error log file in folder
      fprintf(errorLog,'Error on %s %s (n=%i) [catch]',...
                fecha,hora,n); %creating header
      fclose(errorLog); 
   end

   try
      delete(AI);
      clear AI channels;
   catch exception
      errorLog=fopen([carpeta '\Error-log.txt'],'at'); %creating error log file in folder
      fprintf(errorLog,'Error on %s %s (n=%i) [delte(AI)]',...
                fecha,hora,n); %creating header
      fclose(errorLog); 
   end
      
end %end main loop
beep;
