%% Info progetto
% Title: Progetto ESI #3 - Sviluppo algoritmo di riconoscimento di canzoni
% Authors: Fabio Livorno - VR400998 | Filippo Lovato - VR399011
% Last modified: 20/08/2020

%% Variabili contenenti i path relativi a canzoni e clip
songs_dir = 'C:\Users\livor\OneDrive\Desktop\ESI #3 - VR400998 VR399011\mp3_files\mp3_songs';
clip_dir = 'C:\Users\livor\OneDrive\Desktop\ESI #3 - VR400998 VR399011\mp3_files\mp3_dirty_test';

%% Lettura directory contenente le clip e caricamento
cd(clip_dir);
clip_list = dir('*.mp3');
n_clip = size(clip_list, 1); 
clip_names = ["Io centro con i missili","Radioactive","Ultraviolence","Veronica n2","We Are Young","We Have Candy","Welcome to the Black Parade"];
hit_o = 0; % numero di hit tra clip e canzone originale
hit_n = 0; % numero di hit tra clip con rumore e canzone originale

threshold = cell(n_clip,1);
noise = 0; % variabile per assegnare o meno il rumore al segnale
YNoise = cell(n_clip,2);

for i = 1: n_clip
    
    [YClip{i}, fsClip{i}] = audioread(clip_list(i).name);

    noise = 0; % azzero il livello di rumore per il prossimo ciclo
    fprintf('\nClip "%s" importata correttamente\n', extractBefore(clip_list(i).name,'.mp3'));
    clip_length{i} = length(YClip{i})/fsClip{i};
    fprintf('Lunghezza clip #%d: %d secondo/i\n', i, int8(clip_length{i}));
    
    %applico rumore gaussiano con mu=0 e dev std pari a 6
    for j = 1: 2
       if j == 2
           noise = 1;
       end
       YNoise{i}{j} = YClip{i} + noise * normrnd(0,6,length(YClip{i}),length(fsClip{i}));
    end
    
    clear YClip{:};
    clear fsClip{:};
    
    % assegno diversi livelli di threshold in base alla lunghezza del
    % segmento della clip
    if(int8(clip_length{i}) > 3)
    	threshold{i} = 15000;
    else
        threshold{i} = 4750;
    end
end

%sound(YNoise{6}{2},fsClip{6}); % ascolto la clip con il rumore aggiunto

%% Resample di una traccia per cambiarne la frequenza di campionamento
p = 2;
q = 3;
[YSampling, fsSampling] = resample(YNoise{1}{1},p,q);

%% Lettura directory contenente le canzoni
cd(songs_dir);
song_list = dir('*.mp3');
n_songs = size(song_list, 1); % size(lista, X) se X = 1 -> ritorna numero di righe della lista

%% Inizializzo un ArrayCell che conterrà i possibili hit delle canzoni
match = cell(n_songs,1);

%% Inizializzo variabili per la cross-correlazione
xc = cell(1,n_clip); 
lagc = cell(1,n_clip);
xd = cell(1,n_clip);
lagd = cell(1,n_clip);
maxC = cell(1,n_clip);
maxD = cell(1,n_clip);
songNoC = cell(1,n_clip);
songNoD = cell(1,n_clip);

%% Caricamento canzoni una ad una
i = 1;
t = 0;

tic
while (i <= n_songs)
    
    [Y, fs] = audioread(song_list(i).name);
    fprintf('Brano "%s" importato correttamente\n', extractBefore(song_list(i).name,'.mp3'));
    
    match{i} = Y(:,1); % popolo l'ArrayCell con i segnali audio delle canzoni importate mano a mano che le carico
    clear Y;
    %% Eseguo la cross-correlazione
    fprintf('\t- Esecuzione della cross-correlazione\n');
    
    %fprintf('\t\t- %s\n', extractBefore(song_list(i).name, '.mp3'));
    for j = 1: n_clip
        for k = 1: 2
            
            [xa, laga] = xcorr(match{i}, YNoise{j}{k}(:,1));
            
            if i == 1
                if k == 1
                    xr = xa;
                    lagr = laga;
                    [xs, lags] = xcorr(match{i}, YSampling(:,1), 'none');
                    
                    xc{j} = xa;
                    lagc{j} = laga;
                    maxC{j} = int32(max(xc{j}));
                    songNoC{j} = 1;
                else
                    xd{j} = xa;
                    lagd{j} = laga;
                    maxD{j} = int32(max(xd{j}));
                    songNoD{j} = 1;
                    fprintf('---> corrispondenza | j: %i; maxC: %d; maxD: %d\n', j, maxC{j}, maxD{j});
                end
            elseif i ~= 1
                if k == 1
                    if int32(max(xa)) > maxC{j}
                        songNoC{j} = i;
                        xc{j} = xa;
                        lagc{j} = laga;
                        fprintf('---> corrispondenza | j: %i ; k: %i ; old_maxC: %d; new_maxC: %d\n', j, k, maxC{j}, int32(max(xc{j})));
                        maxC{j} = int32(max(xc{j}));
                    end
                else
                    if int32(max(xa)) > maxD{j}
                        songNoD{j} = i;
                        xd{j} = xa;
                        lagd{j} = laga;
                        fprintf('---> corrispondenza | j: %i ; k: %i ; old_maxD: %d; new_maxD: %d\n', j, k, maxD{j}, int32(max(xd{j})));
                        maxD{j} = int32(max(xd{j}));
                    end
                end
            end
        end
    end
    
i = i + 1;      
end

t = toc;

%% Stampo gli esiti della cross-correlazione
fprintf('\n\nElaborazione completata in %d secondi\n', int8(t));
for j = 1: n_clip
    fprintf('\nClip "%s"\n', extractBefore(clip_list(j).name,'.mp3'));
    for k = 1: 2
        
        fprintf('------------------ k = %i ------------------\n', k);
        if k == 1
            
            fprintf('%s%d: %d', 'valore di cross correlazione per la clip #' , j, int32(maxC{j}));
            if int32(maxC{j}) >= threshold{j}
                fprintf("\ncorrispondenza trovata con il brano: %s\n", extractBefore(song_list(songNoC{j}).name, '.mp3'));
                if contains(extractBefore(song_list(songNoC{j}).name, '.mp3'),clip_names(j),'IgnoreCase',true)
                    hit_o = hit_o + 1;
                end
            elseif int32(maxC{j}) < threshold{j}
                fprintf("\nnessuna corrispondenza trovata\n");
            end
        else
            
            fprintf('%s%d: %d', 'valore di cross correlazione per la clip #' , j, int32(maxD{j}));
            if int32(maxD{j}) >= threshold{j}
                fprintf("\ncorrispondenza trovata con il brano: %s\n", extractBefore(song_list(songNoD{j}).name, '.mp3'));
                if contains(extractBefore(song_list(songNoD{j}).name, '.mp3'),clip_names(j),'IgnoreCase',true)
                    hit_n = hit_n + 1;
                end
            elseif int32(maxD{j}) < threshold{j}
                fprintf("\nnessuna corrispondenza trovata\n");
            end
        end
    end
end

%% Disegno i grafici
accuracy = [hit_o/n_clip hit_n/n_clip]; %Vettore contenente l'accuratezza sulle clip con e senza rumore
noise_vector = [0 1]; %Vettore contenente il rumore aggiunto

clip_length_vector = [1 3 5 10 20 30]; %Vettore contenente la lunghezza della clip
accuracy_clip_length = [1/1 1/1 1/1 2/2 1/1 1/1]; %Vettore contenente l'accuratezza sulla lunghezza della clip

% Prima finestra: Accuracy
figure('Name', 'Accuratezza (casi giusti/casi totali) con e senza rumore');
subplot(2,1,1);
plot(noise_vector, accuracy);
title('Casi giusti | Rumore');
xlim([0 1]);
xlabel('Noise Vector');
ylim([0 2]);
ylabel('Accuracy');

subplot(2,1,2);
plot(clip_length_vector, accuracy_clip_length);
title('Casi giusti | Lunghezza clip');
xlim([1 30]);
xlabel('Clip Length (s)');
ylim([0 2]);
ylabel('Accuracy');

% Seconda finestra: Cross-correlazione della clip #1

figure('Name', 'Cross-correlazione tra canzone e clip da 10s');
subplot(3,1,1);
plot(match{songNoC{1}});
title('Segnale audio intero');
xlabel('Samples');
subplot(3,1,2);
plot(YNoise{1}{1});
title('Clip 10s');
xlabel('Samples');
subplot(3,1,3);
plot(lagc{1},xc{1});
title('xcorr');
xlabel('Indice di lag');

%% Cross-correlazioni dello stesso segnale con diverse campionature

figure('Name', 'Grafico YSampling');
subplot(5,1,1);
plot(match{1});
title('Cross-correlazioni dello stesso sample con diverse campionature');
xlabel('Canzone con la quale effettuo la cross-correlazione');
subplot(5,1,2);
plot(YNoise{1}{1});
xlabel('Sample con campionatura reale');
subplot(5,1,3);
plot(YSampling);
xlabel('Sample ri-campionato');
subplot(5,1,4);
plot(lagr,xr);
xlabel('Cross-correlazione del sample originale');
subplot(5,1,5);
plot(lags,xs);
xlabel('Cross-correlazione del sample ri-campionato');

%% Clip senza e con rumore

figure('Name', 'Sample senza e con rumore');
subplot(2,1,1);
plot(YNoise{1}{1});
xlabel('Sample privo di rumore');
subplot(2,1,2);
plot(YNoise{1}{2});
xlabel('Sample con rumore');