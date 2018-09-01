close all
clear all
daqreset
%uso este para ver los valores de umbral y para calibrar el trigger
%y el umbral para dejar de grabar
duration = 3; %tiempo que se quiere monitorear
ventana=1;%tiempo de la ventana a analizar si hay silencio
AI = analoginput('nidaq','Dev1');
chan = addchannel(AI,[3 2]);
set(AI,'SampleRate',44150);
ActualRate = floor(get(AI,'SampleRate'));
set(AI,'SamplesPerTrigger',ceil(duration*ActualRate))
blocksize = get(AI,'SamplesPerTrigger');
tiempo_ventana=1 %tiempo en segundos de la ventana en la qeu se fija si hay canto o no
%--------------------------------------------------------------------
start(AI)
%wait(AI,duration + 1)
[data time] = getdata(AI);
delete(AI)
clear AI
%hace un plot de los datos, para ver a ojo cual es el umbral
max(data) %este es el umbral a lo cuadrado
%wavwrite(data,44150,'prusonffso.wav');
subplot(411),plot(time,data(:,1)); %plotea canal 1
subplot(412),plot(time,data(:,2)); %plotea canal 2
emg=data(:,2);
son=data(:,1);
[sS,F,T,P] = spectrogram(son,1024,512,1024,ActualRate);
subplot(413),surf(T,F,10*log10(abs(P)),'edgecolor','none'); axis tight;
view(0,90);
ylim([0 6000])
% subplot(312), spectrogram(son,1024,800,ActualRate),view(0,90);
N=length(son)/(ActualRate*tiempo_ventana);
for i=1:N
    S(i)=sum(abs(son(1+(i-1)*ActualRate*tiempo_ventana:i*ActualRate*tiempo_ventana)));
end
subplot(414),plot(S,'.') % de este plot se elegir el umbral de la ventana apropiado
wavwrite(normalizaruncanal(son),ActualRate,'pru.wav');
