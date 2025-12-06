function preprocess_data(base_path, years, quarters)
%% ========================================================================
%  PREPROCESS_DATA: Convierte archivos NetCDF de ERA5 a formato MAT
%  ========================================================================
%  Entradas:
%    base_path - Ruta base donde están los datos NetCDF
%    years     - Vector de años a procesar (ej: 2004:2012)
%    quarters  - Cell array de trimestres (ej: {'01-03', '04-06', ...})
%
%  Salida:
%    Archivos .mat guardados en carpeta 'datos_procesados'
%% ========================================================================

fprintf('\nPreprocesando datos NetCDF...\n');

% Crear carpeta de salida
output_folder = fullfile(base_path, 'datos_procesados');
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
    fprintf('  Carpeta creada: %s\n', output_folder);
end

% Contador de éxitos y errores
count_success = 0;
count_errors = 0;

% Procesar cada año y trimestre
for year = years
    for q = 1:length(quarters)
        quarter = quarters{q};
        
        folder_path = fullfile(base_path, num2str(year), quarter);
        
        % Construir rutas de archivos NetCDF
        filename_instant = fullfile(folder_path, 'data_stream-oper_stepType-instant.nc');
        filename_accum = fullfile(folder_path, 'data_stream-oper_stepType-accum.nc');
        
        % Verificar que los archivos existan
        if ~isfile(filename_instant) || ~isfile(filename_accum)
            fprintf('  ⚠ Archivos no encontrados: %d %s\n', year, quarter);
            count_errors = count_errors + 1;
            continue;
        end
        
        try
            % =============== LEER DATOS INSTANTÁNEOS ===============
            u10 = ncread(filename_instant, 'u10');   % Componente u del viento
            v10 = ncread(filename_instant, 'v10');   % Componente v del viento
            d2m = ncread(filename_instant, 'd2m');   % Temperatura punto de rocío
            t2m = ncread(filename_instant, 't2m');   % Temperatura del aire
            tcc = ncread(filename_instant, 'tcc');   % Cobertura total de nubes
            
            % =============== LEER DATOS ACUMULADOS ===============
            tp = ncread(filename_accum, 'tp');       % Precipitación total
            
            % =============== LEER DIMENSIONES ===============
            time = ncread(filename_instant, 'valid_time');
            latitude = ncread(filename_instant, 'latitude');
            longitude = ncread(filename_instant, 'longitude');
            
            % =============== CONVERSIONES DE UNIDADES ===============
            % Temperaturas de Kelvin a Celsius
            t2m = t2m - 273.15;
            d2m = d2m - 273.15;
            
            % Precipitación de m a mm
            tp = tp * 1000;
            
            % Cobertura de nubes de fracción (0-1) a Oktas (0-8)
            tcc = tcc * 8;
            
            % Calcular velocidad del viento: sqrt(u² + v²)
            wind_speed = sqrt(u10.^2 + v10.^2);
            
            % =============== CREAR ESTRUCTURA DE DATOS ===============
            weather_data = struct();
            weather_data.time = time;
            weather_data.latitude = latitude;
            weather_data.longitude = longitude;
            weather_data.tp = tp;
            weather_data.u10 = u10;
            weather_data.v10 = v10;
            weather_data.d2m = d2m;
            weather_data.t2m = t2m;
            weather_data.tcc = tcc;
            weather_data.wind_speed = wind_speed;
            
            % =============== GUARDAR ARCHIVO MAT ===============
            output_filename = sprintf('%d %s.mat', year, quarter);
            output_path = fullfile(output_folder, output_filename);
            save(output_path, 'weather_data');
            
            fprintf('  ✓ Procesado: %d %s\n', year, quarter);
            count_success = count_success + 1;
            
        catch ME
            fprintf('  ✗ Error en %d %s: %s\n', year, quarter, ME.message);
            count_errors = count_errors + 1;
        end
    end
end

% Resumen final
fprintf('\n--- RESUMEN DE PREPROCESO ---\n');
fprintf('  Archivos procesados exitosamente: %d\n', count_success);
fprintf('  Archivos con errores: %d\n', count_errors);
fprintf('  Total intentados: %d\n', count_success + count_errors);

end