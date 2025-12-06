%% ========================================================================
%  PIPELINE COMPLETO: Preproceso + Cálculo de Rocío + Análisis Anual
%  ========================================================================
%  Este script controla todo el flujo de trabajo:
%  1. Preproceso de datos NetCDF a MAT (opcional)
%  2. Cálculo de rocío para cada trimestre
%  3. Generación de gráficos y resumen anual
%% ========================================================================

close all;
clear;
clc;

%% ======================== CONFIGURACIÓN ================================

% --- Opción 1: Ejecutar preproceso (convertir .nc a .mat) ---
EJECUTAR_PREPROCESO = true;  % Cambiar a true si necesitas procesar .nc
base_path_nc = 'C:\Users\salin\OneDrive\Desktop\git dew';
years_preproceso = 2004:2004;

% --- Opción 2: Años para análisis de rocío ---
% years_analisis = {'2019', '2020', '2021', '2022', '2023', '2024'};
% years_analisis = {'2004','2005','2006','2007','2008','2009','2010','2011','2012','2013','2014','2015','2016','2017','2018'};
years_analisis = {'2004'};
quarters = {'01-03', '04-06', '07-09', '10-12'};

% --- Carpeta para resultados anuales ---
carpeta_resultados = 'resultados_anuales';
if ~exist(carpeta_resultados, 'dir')
    mkdir(carpeta_resultados);
end

%% =================== PASO 1: PREPROCESO (OPCIONAL) ====================

if EJECUTAR_PREPROCESO
    fprintf('\n=== INICIANDO PREPROCESO DE DATOS NetCDF ===\n');
    try
        preprocess(base_path_nc, years_preproceso, quarters);
        fprintf('✓ Preproceso completado exitosamente\n\n');
    catch ME
        fprintf('✗ Error en preproceso: %s\n', ME.message);
        return;
    end
else
    fprintf('\n=== SALTANDO PREPROCESO (archivos .mat ya existen) ===\n\n');
end

%% ============== PASO 2: CÁLCULO DE ROCÍO POR AÑO =======================

fprintf('=== INICIANDO CÁLCULO DE ROCÍO ===\n');

% Resultados globales
resultados_todos = struct();

for ny = 1:length(years_analisis)
    year_actual = years_analisis{ny};
    fprintf('\n--- Procesando año %s ---\n', year_actual);
    
    total_rocio = 0;
    total_lluvia = 0;
    rocio_dia_anual = [];
    lluvia_dia_anual = [];
    
    % Procesar cada trimestre
    for nm = 1:length(quarters)
        quarter_actual = quarters{nm};
        fprintf('  Trimestre %s... ', quarter_actual);
        
        try
            [acum_lluvia, acum_rocio] = compute_dew(year_actual, quarter_actual);
            
            % Sumar totales del trimestre
            total_rocio = total_rocio + acum_rocio(end);
            total_lluvia = total_lluvia + acum_lluvia(end);
            
            % Concatenar acumulados diarios
            if isempty(rocio_dia_anual)
                rocio_dia_anual = acum_rocio;
                lluvia_dia_anual = acum_lluvia;
            else
                % Mantener continuidad del acumulado
                rocio_dia_anual = [rocio_dia_anual; acum_rocio + rocio_dia_anual(end)];
                lluvia_dia_anual = [lluvia_dia_anual; acum_lluvia + lluvia_dia_anual(end)];
            end
            
            fprintf('✓\n');
        catch ME
            fprintf('✗ Error: %s\n', ME.message);
            continue;
        end
    end
    
    %% ============== PASO 3: GRÁFICOS Y RESUMEN ANUAL ===================
    
    % Guardar resultados
    resultados_todos.(sprintf('year_%s', year_actual)) = struct(...
        'total_rocio', total_rocio, ...
        'total_lluvia', total_lluvia, ...
        'rocio_dia', rocio_dia_anual, ...
        'lluvia_dia', lluvia_dia_anual);
    
    % Crear gráfico de rocío y lluvia acumulados
    figure('Position', [100 100 1000 600]);
    
    yyaxis left
    plot(lluvia_dia_anual, 'b', 'LineWidth', 2.5);
    ylabel('Lluvia acumulada (mm)', 'FontSize', 12);
    ylim([0 max(lluvia_dia_anual)*1.1]);
    
    yyaxis right
    plot(rocio_dia_anual, 'r', 'LineWidth', 2);
    ylabel('Rocío acumulado (mm)', 'FontSize', 12);
    ylim([0 max(rocio_dia_anual)*1.1]);
    
    xlabel('Días', 'FontSize', 12);
    title(sprintf('Año %s | Rocío total: %.1f mm | Lluvia total: %.1f mm', ...
        year_actual, total_rocio, total_lluvia), 'FontSize', 14);
    legend('Lluvia', 'Rocío', 'Location', 'northwest');
    grid on;
    set(gca, 'FontSize', 11, 'FontName', 'Times New Roman');
    
    % Guardar gráficos
    nombre_pdf = fullfile(carpeta_resultados, sprintf('acumulado_%s.pdf', year_actual));
    nombre_png = fullfile(carpeta_resultados, sprintf('acumulado_%s.png', year_actual));
    exportgraphics(gcf, nombre_pdf, 'ContentType', 'vector', 'BackgroundColor', 'white');
    print(nombre_png, '-dpng', '-r300');
    
    % Mostrar resumen en consola
    fprintf('\n  RESUMEN AÑO %s:\n', year_actual);
    fprintf('    • Rocío total:  %.2f mm\n', total_rocio);
    fprintf('    • Lluvia total: %.2f mm\n', total_lluvia);
    fprintf('    • Ratio Rocío/Lluvia: %.2f%%\n\n', (total_rocio/total_lluvia)*100);
end

%% =================== PASO 4: RESUMEN GLOBAL ============================

fprintf('\n=== RESUMEN GLOBAL DE TODOS LOS AÑOS ===\n');
fprintf('%-10s %15s %15s %15s\n', 'Año', 'Rocío (mm)', 'Lluvia (mm)', 'Ratio (%)');
fprintf('%-10s %15s %15s %15s\n', '----', '----------', '-----------', '---------');

for ny = 1:length(years_analisis)
    year_actual = years_analisis{ny};
    datos = resultados_todos.(sprintf('year_%s', year_actual));
    ratio = (datos.total_rocio / datos.total_lluvia) * 100;
    fprintf('%-10s %15.2f %15.2f %15.2f\n', ...
        year_actual, datos.total_rocio, datos.total_lluvia, ratio);
end

% Guardar resultados en archivo .mat
save(fullfile(carpeta_resultados, 'resultados_completos.mat'), 'resultados_todos');

fprintf('\n✓ PIPELINE COMPLETADO EXITOSAMENTE\n');
fprintf('  Resultados guardados en: %s\n\n', carpeta_resultados);