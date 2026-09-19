classdef GraftCal < matlab.apps.AppBase
    properties (Access = public)
        UIFigure
        ButtonPanel
        ImportDataBtn, ImportSolventsBtn, RunSolverBtn, ExportBtn, ClearBtn
        AppTitleLabel
        LeftPanel
        DataPanel, DataTitleLabel, DataStatusLabel, DataTable
        SolventsPanel, SolventsTitleLabel, SolventsStatusLabel, SolventsTable
        LogPanel, LogTitleLabel, LogTextArea
        MiddlePanel
        ParametersPanel, ParamTitleLabel, ParamLabels, ParamFields
        RightPanel
        ResultsPanel, ResultsTitleLabel, DatasetLabel, DatasetDropdown, ResultsTable
        PlotsPanel, PlotsTitleLabel, SolventLabel, SolventDropdown, UIAxes1, UIAxes2, UIAxes3, UIAxes4
    end

    properties (Access = private)
        dataTable = table()
        solvents = []
        resultTable = table()
        exportTable = table()
        GD_solved = []
        slope_neff = []
        R2_neff = []
        neff_all = {}
        
        colorDarkBlue = [0.10 0.15 0.28]
        colorBlue = [0.16 0.48 0.88]
        colorGreen = [0.08 0.65 0.40]
        colorOrange = [0.85 0.45 0.05]
        colorPurple = [0.55 0.25 0.85]
        colorGray = [0.50 0.52 0.60]
        colorLightGray = [0.94 0.95 0.97]
        colorText = [0.08 0.10 0.15]
    end

    methods (Access = public)
        function app = GraftCal()
            app.createUI();
            registerApp(app, app.UIFigure);
            app.initializeApp();
            app.showStartupDialog();
        end
        
        function delete(app)
            delete(app.UIFigure);
        end
    end

    methods (Access = private)
        
        function addLog(app, msg)
            current = app.LogTextArea.Value;
            if ischar(current), current = cellstr(current); end
            if isempty(current), current = {}; end
            % FIXED: Use datetime instead of datestr for proper timestamp
            time = string(datetime('now', 'Format', 'HH:mm:ss'));
            app.LogTextArea.Value = [current; {sprintf('[%s] %s', time, msg)}];
            
            % Auto-scroll to bottom to show latest message
            drawnow;
            app.LogTextArea.scroll('bottom');
        end
        
        function disableAllButtons(app)
            % Disable all buttons and make them gray during solver execution
            app.ImportDataBtn.Enable = 'off';
            app.ImportSolventsBtn.Enable = 'off';
            app.RunSolverBtn.Enable = 'off';
            app.ExportBtn.Enable = 'off';
            app.ClearBtn.Enable = 'off';
            
            % Change button colors to gray
            app.ImportDataBtn.BackgroundColor = [0.7 0.7 0.7];
            app.ImportSolventsBtn.BackgroundColor = [0.7 0.7 0.7];
            app.RunSolverBtn.BackgroundColor = [0.7 0.7 0.7];
            app.ExportBtn.BackgroundColor = [0.7 0.7 0.7];
            app.ClearBtn.BackgroundColor = [0.7 0.7 0.7];
            
            % Change text color to darker gray for disabled appearance
            app.ImportDataBtn.FontColor = [0.5 0.5 0.5];
            app.ImportSolventsBtn.FontColor = [0.5 0.5 0.5];
            app.RunSolverBtn.FontColor = [0.5 0.5 0.5];
            app.ExportBtn.FontColor = [0.5 0.5 0.5];
            app.ClearBtn.FontColor = [0.5 0.5 0.5];
            
            drawnow;
        end
        
        function enableAllButtons(app)
            % Re-enable all buttons and restore original colors
            app.ImportDataBtn.Enable = 'on';
            app.ImportSolventsBtn.Enable = 'on';
            app.RunSolverBtn.Enable = 'on';
            app.ExportBtn.Enable = 'on';
            app.ClearBtn.Enable = 'on';
            
            % Restore original button colors
            app.ImportDataBtn.BackgroundColor = app.colorBlue;
            app.ImportSolventsBtn.BackgroundColor = app.colorGreen;
            app.RunSolverBtn.BackgroundColor = app.colorOrange;
            app.ExportBtn.BackgroundColor = app.colorPurple;
            app.ClearBtn.BackgroundColor = app.colorGray;
            
            % Restore text color to white
            app.ImportDataBtn.FontColor = [1 1 1];
            app.ImportSolventsBtn.FontColor = [1 1 1];
            app.RunSolverBtn.FontColor = [1 1 1];
            app.ExportBtn.FontColor = [1 1 1];
            app.ClearBtn.FontColor = [1 1 1];
            
            drawnow;
        end
        
        function initializeApp(app)
            defaults = [7, 3.05, 0.95, 1.5993, 65, 1e-4, 0.001, 2e5];
            names = {'Radius of Nanoparticles (nm)', 'Decay Length L (nm)', 'Effective Polymer Segment Diameter b (nm)', ...
                'Refractive Index of Polymer', 'Target Slope', 'Tolerance', 'dz (nm)', 'Max Iterations'};
            
            for i = 1:length(defaults)
                app.ParamLabels{i}.Text = names{i};
                app.ParamFields{i}.Value = defaults(i);
            end
            
            app.addLog('GraftCal Ready');
        end
        
        function showStartupDialog(app)
            % Get screen size and center dialog
            screenSize = get(0, 'ScreenSize');
            screenW = screenSize(3);
            screenH = screenSize(4);
            
            dlgW = 850;
            dlgH = 820;
            dlgX = (screenW - dlgW) / 2;
            dlgY = (screenH - dlgH) / 2;
            
            % Create startup popup dialog centered on screen with scrollable content
            dlg = uifigure('Position', [dlgX dlgY dlgW dlgH], 'Name', 'GraftCal - User Guide', ...
                'NumberTitle', 'off', 'Resize', 'off', 'WindowStyle', 'modal');
            dlg.Color = [0.95 0.96 0.98];
            
            % Main Title
            titleLbl = uilabel(dlg, 'Position', [20 dlgH-70 dlgW-40 60], ...
                'Text', '📊 GraftCal - Graft Density Analysis Tool', ...
                'FontSize', 24, 'FontWeight', 'bold', 'FontColor', [0.10 0.15 0.28], ...
                'HorizontalAlignment', 'center', 'FontName', 'Segoe UI');
            
            % Create scrollable text area
            instrTextArea = uitextarea(dlg, 'Position', [20 80 dlgW-40 dlgH-160], ...
                'FontSize', 15, 'FontColor', [0.08 0.10 0.15], ...
                'BackgroundColor', [1 1 1], 'Editable', 'off', 'FontName', 'Consolas', ...
                'FontWeight', 'normal');
            
            % Full detailed instructions text with properly aligned monospace tables
            instructionText = sprintf(['📋 STEP 1: PREPARE YOUR DATA FILE\n', ...
                '\n', ...
                'Create a CSV or Excel file with experimental data:\n', ...
                '\n', ...
                '  Column 1: H (in nm)\n', ...
                '    Shell Thickness: Difference between PGNP hydrodynamic radius\n', ...
                '    and bare nanoparticle core\n', ...
                '\n', ...
                '  Column 2+: Lambda Max values (peak position) (in nm)\n', ...
                '    Wavelength measurements for each solvent\n', ...
                '    (minimum 2 solvents required)\n', ...
                '\n', ...
                'EXAMPLE DATA TABLE:\n', ...
                '\n', ...
                '  ┌─────────┬──────────────┬──────────────┬──────────────┐\n', ...
                '  │    H    │   Lambda1    │   Lambda2    │   Lambda3    │\n', ...
                '  │   (nm)  │    (nm)      │    (nm)      │    (nm)      │\n', ...
                '  ├─────────┼──────────────┼──────────────┼──────────────┤\n', ...
                '  │  15.5   │    300.2     │    320.1     │    350.8     │\n', ...
                '  │  20.3   │    305.6     │    325.3     │    355.2     │\n', ...
                '  │  25.1   │    310.4     │    330.2     │    360.1     │\n', ...
                '  └─────────┴──────────────┴──────────────┴──────────────┘\n', ...
                '\n', ...
                '🧪 STEP 2: PREPARE YOUR SOLVENTS FILE\n', ...
                '\n', ...
                'Create a CSV or Excel file with solvent refractive indices:\n', ...
                '\n', ...
                '  • ONE ROW ONLY with all refractive index values\n', ...
                '  • Column headers: n_solv_1, n_solv_2, n_solv_3\n', ...
                '\n', ...
                'EXAMPLE SOLVENTS TABLE:\n', ...
                '\n', ...
                '  ┌──────────────┬──────────────┬──────────────┐\n', ...
                '  │  n_solv_1    │  n_solv_2    │  n_solv_3    │\n', ...
                '  ├──────────────┼──────────────┼──────────────┤\n', ...
                '  │    1.33      │    1.45      │    1.55      │\n', ...
                '  └──────────────┴──────────────┴──────────────┘\n', ...
                '\n', ...
                '📂 STEP 3: IMPORT DATA AND SOLVENTS\n', ...
                '\n', ...
                '  1. Click "📂 Data" → Select data CSV/Excel file\n', ...
                '  2. Click "🧪 Solvents" → Select solvents CSV/Excel file\n', ...
                '\n', ...
                '⚙️  STEP 4: CONFIGURE SOLVER PARAMETERS\n', ...
                '\n', ...
                '  • Radius of Nanoparticle Core (R_NP)\n', ...
                '    Core radius of bare nanoparticle (nm)\n', ...
                '\n', ...
                '  • Decay Length (L)\n', ...
                '    The distance over which the plasmonic near-field intensity\n', ...
                '    decreases by a factor of e from the nanoparticle surface\n', ...
                '\n', ...
                '  • Effective Polymer Segment Diameter (b)\n', ...
                '    Effective diameter used for the polymer segment cross-section\n', ...
                '\n', ...
                '  • Refractive Index of Polymer\n', ...
                '    Refractive index of polymer\n', ...
                '\n', ...
                '  • Target Slope\n', ...
                '    Linear slope of peak shifts as a function of solvent\n', ...
                '    refractive index, as predicted from Mie Theory or\n', ...
                '    measured experimentally\n', ...
                '\n', ...
                '  • Tolerance\n', ...
                '    Solver precision (smaller = more precise)\n', ...
                '\n', ...
                '  • dz (nm)\n', ...
                '    Spatial step size for integrating the effective\n', ...
                '    refractive index\n', ...
                '\n', ...
                '  • Max Iterations\n', ...
                '    Maximum solver cycles\n', ...
                '\n', ...
                '▶️  STEP 5: RUN THE SOLVER\n', ...
                '\n', ...
                '  Click "⚙️  Solve" button:\n', ...
                '  • Progress shown in log panel\n', ...
                '  • Four analysis plots appear automatically\n', ...
                '  • Use Solvent dropdown to view different profiles\n', ...
                '\n', ...
                '💾 STEP 6: EXPORT RESULTS\n', ...
                '\n', ...
                '  Click "💾 Export":\n', ...
                '  • Save as an Excel file\n', ...
                '  • Multiple sheets with data and analysis\n', ...
                '  • Progress bar shows export status\n']);
            
            % Set text area content
            instrTextArea.Value = instructionText;
            
            % Bottom action bar
            actionPanel = uipanel(dlg, 'Position', [0 0 dlgW 75], ...
                'BorderType', 'none', 'BackgroundColor', [0.90 0.92 0.95]);
            
            % Email link as clickable button styled as link
            emailBtn = uibutton(actionPanel, 'push', ...
                'Position', [20 18 260 45], ...
                'Text', '📧 masoud.abdi@uri.edu', ...
                'FontSize', 11, 'FontColor', [0.16 0.48 0.88], 'FontWeight', 'bold', ...
                'BackgroundColor', [0.90 0.92 0.95], ...
                'HorizontalAlignment', 'left', 'FontName', 'Segoe UI');
            emailBtn.ButtonPushedFcn = @(~,~) web('mailto:masoud.abdi@uri.edu');
            
            % Start button
            closeBtn = uibutton(actionPanel, 'push', ...
                'Position', [dlgW-280 15 260 50], ...
                'Text', '▶️  Start Using App', ...
                'FontSize', 12, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.08 0.65 0.40], ...
                'FontColor', [1 1 1], 'FontName', 'Segoe UI');
            closeBtn.ButtonPushedFcn = @(~,~) delete(dlg);
        end
        
        function importDataCallback(app)
            [file, path] = uigetfile({'*.csv;*.xlsx;*.xls', 'Data Files'});
            if isequal(file, 0), return; end
            
            % Bring app window to focus
            figure(app.UIFigure);
            
            try
                fullPath = fullfile(path, file);
                [~, ~, ext] = fileparts(fullPath);
                
                if strcmpi(ext, '.csv')
                    T = readtable(fullPath);
                else
                    T = readtable(fullPath, 'Sheet', 1);
                end
                
                T.Properties.VariableNames = matlab.lang.makeValidName(T.Properties.VariableNames);
                
                if ~ismember('H_nm', T.Properties.VariableNames)
                    if ismember('H', T.Properties.VariableNames)
                        idx = find(strcmp(T.Properties.VariableNames, 'H'));
                        T.Properties.VariableNames{idx} = 'H_nm';
                    else
                        app.addLog('ERROR: Missing H_nm column');
                        return;
                    end
                end
                
                lambdaCols = startsWith(T.Properties.VariableNames, 'lambda', 'IgnoreCase', true);
                if sum(lambdaCols) < 2
                    app.addLog('ERROR: Need 2+ lambda columns');
                    return;
                end
                
                app.dataTable = T;
                app.DataTable.Data = T;
                app.DataStatusLabel.Text = ['✓ ' file];
                app.DataStatusLabel.FontColor = app.colorGreen;
                
                nDatasets = height(T);
                % Create dataset items as strings
                datasetItems = cellstr(num2str((1:nDatasets)'));
                app.DatasetDropdown.Items = datasetItems;
                % Set value after items are populated
                if ~isempty(datasetItems)
                    app.DatasetDropdown.Value = datasetItems{1};
                end
                
                app.addLog(sprintf('Data: %s (%d rows)', file, nDatasets));
                
            catch ME
                app.addLog(['Error: ' ME.message]);
            end
        end
        
        function importSolventsCallback(app)
            [file, path] = uigetfile({'*.csv;*.xlsx;*.xls', 'Data Files'});
            if isequal(file, 0), return; end
            
            % Bring app window to focus
            figure(app.UIFigure);
            
            try
                fullPath = fullfile(path, file);
                [~, ~, ext] = fileparts(fullPath);
                
                if strcmpi(ext, '.csv')
                    T = readtable(fullPath);
                else
                    T = readtable(fullPath, 'Sheet', 1);
                end
                
                T.Properties.VariableNames = matlab.lang.makeValidName(T.Properties.VariableNames);
                
                solvCols = startsWith(T.Properties.VariableNames, 'n_solv', 'IgnoreCase', true);
                if sum(solvCols) < 2
                    app.addLog('ERROR: Need 2+ n_solv columns');
                    return;
                end
                
                solvNames = T.Properties.VariableNames(solvCols);
                nValues = table2array(T(1, solvNames));
                
                if any(isnan(nValues))
                    app.addLog('ERROR: NaN in solvents');
                    return;
                end
                
                app.solvents = nValues(:)';
                app.SolventsTable.Data = T(1, solvNames);
                app.SolventsStatusLabel.Text = ['✓ ' file];
                app.SolventsStatusLabel.FontColor = app.colorGreen;
                
                % Populate solvent dropdown in Plots panel
                nSolvents = length(nValues);
                solventLabels = {};
                for i = 1:nSolvents
                    solventLabels{i} = sprintf('Solvent %d (n=%.4f)', i, nValues(i));
                end
                app.SolventDropdown.Items = solventLabels;
                app.SolventDropdown.Value = solventLabels{1};
                
                app.addLog(sprintf('Solvents: %d values', length(nValues)));
                
            catch ME
                app.addLog(['Error: ' ME.message]);
            end
        end
        
        function runSolverCallback(app)
            if isempty(app.dataTable)
                app.addLog('Load data first');
                return;
            end
            if isempty(app.solvents)
                app.addLog('Load solvents first');
                return;
            end
            
            Rc = app.ParamFields{1}.Value;
            L = app.ParamFields{2}.Value;
            b = app.ParamFields{3}.Value;
            n_poly = app.ParamFields{4}.Value;
            targetSlope = app.ParamFields{5}.Value;
            tolerance = app.ParamFields{6}.Value;
            dz = app.ParamFields{7}.Value;
            maxIter = round(app.ParamFields{8}.Value);
            
            % VALIDATION: Check for zero and negative values on ALL parameters
            if Rc == 0
                app.addLog('❌ ERROR: Radius of Nanoparticles (R_NP) cannot be zero');
                return;
            end
            if Rc < 0
                app.addLog('❌ ERROR: Radius of Nanoparticles (R_NP) cannot be negative');
                return;
            end
            
            if L == 0
                app.addLog('❌ ERROR: Decay Length (L) cannot be zero');
                return;
            end
            if L < 0
                app.addLog('❌ ERROR: Decay Length (L) cannot be negative');
                return;
            end
            
            if b == 0
                app.addLog('❌ ERROR: Radius of Polymer Chain (b) cannot be zero');
                return;
            end
            if b < 0
                app.addLog('❌ ERROR: Radius of Polymer Chain (b) cannot be negative');
                return;
            end
            
            if n_poly == 0
                app.addLog('❌ ERROR: Refractive Index of Polymer (n_poly) cannot be zero');
                return;
            end
            if n_poly < 0
                app.addLog('❌ ERROR: Refractive Index of Polymer (n_poly) cannot be negative');
                return;
            end
            
            if targetSlope == 0
                app.addLog('❌ ERROR: Target Slope cannot be zero');
                return;
            end
            if targetSlope < 0
                app.addLog('❌ ERROR: Target Slope cannot be negative');
                return;
            end
            
            if tolerance == 0
                app.addLog('❌ ERROR: Tolerance cannot be zero');
                return;
            end
            if tolerance < 0
                app.addLog('❌ ERROR: Tolerance cannot be negative');
                return;
            end
            
            if dz == 0
                app.addLog('❌ ERROR: dz (nm) cannot be zero');
                return;
            end
            if dz < 0
                app.addLog('❌ ERROR: dz (nm) cannot be negative');
                return;
            end
            
            if maxIter == 0
                app.addLog('❌ ERROR: Max Iterations cannot be zero');
                return;
            end
            if maxIter < 0
                app.addLog('❌ ERROR: Max Iterations cannot be negative');
                return;
            end
            
            % DISABLE ALL BUTTONS DURING EXECUTION
            app.disableAllButtons();
            
            try
                app.addLog('⏳ Running solver...');
                
                T = app.dataTable;
                lambdaCols = startsWith(T.Properties.VariableNames, 'lambda', 'IgnoreCase', true);
                lambdaNames = T.Properties.VariableNames(lambdaCols);
                lambdaMatrix = table2array(T(:, lambdaNames));
                H = T.H_nm;
                nDatasets = height(T);
                ns = app.solvents;
                
                if size(lambdaMatrix, 2) ~= length(ns)
                    app.addLog('Column mismatch');
                    app.enableAllButtons();
                    return;
                end
                
                GD = zeros(nDatasets, 1);
                slopes = NaN(nDatasets, 1);
                R2values = NaN(nDatasets, 1);
                neff_cell = cell(nDatasets, 1);
                
                for i = 1:nDatasets
                    z = app.makeZGrid(H(i), dz);
                    lambdaData = lambdaMatrix(i, :);
                    
                    if any(isnan(lambdaData))
                        neff_cell{i} = NaN(size(ns));
                        continue;
                    end
                    
                    [GD(i), fitData, neff] = app.solveGD(z, Rc, b, H(i), L, n_poly, ns, ...
                        lambdaData, targetSlope, tolerance, maxIter);
                    slopes(i) = fitData.slope;
                    R2values(i) = fitData.R2;
                    neff_cell{i} = neff;
                end
                
                app.GD_solved = GD;
                app.slope_neff = slopes;
                app.R2_neff = R2values;
                app.neff_all = neff_cell;
                
                resultTable = table(H, GD, slopes, R2values, ...
                    'VariableNames', {'H_nm', 'GD_solved', 'Slope', 'R2'});
                app.resultTable = resultTable;
                app.exportTable = [T, resultTable(:, {'GD_solved', 'Slope', 'R2'})];
                
                app.ResultsTable.Data = resultTable;
                app.updatePlots();
                
                app.addLog(sprintf('✅ Done: %d datasets solved successfully', nDatasets));
                
            catch ME
                app.addLog(['❌ Solver error: ' ME.message]);
            end
            
            % RE-ENABLE ALL BUTTONS AFTER EXECUTION
            app.enableAllButtons();
        end
        
        function updatePlots(app)
            if isempty(app.resultTable), return; end
            if isempty(app.solvents)
                app.addLog('Load solvents first before viewing plots');
                return;
            end
            
            try
                idx = str2double(app.DatasetDropdown.Value);
                if isnan(idx) || idx < 1 || idx > height(app.dataTable), return; end
                
                Rc = app.ParamFields{1}.Value;
                L = app.ParamFields{2}.Value;
                b = app.ParamFields{3}.Value;
                n_poly = app.ParamFields{4}.Value;
                dz = app.ParamFields{7}.Value;
                
                T = app.dataTable;
                H = T.H_nm(idx);
                z = app.makeZGrid(H, dz);
                ns = app.solvents;
                
                % Calculate volume fraction once
                GD_idx = app.GD_solved(idx);
                phi = app.calcVolumeFraction(GD_idx, z, Rc, b, H);
                
                % Get selected solvent index from dropdown - with safety check
                solventIdx = 1;  % Default to first solvent
                if ~isempty(app.SolventDropdown.Items)
                    solventIdx = find(strcmp(app.SolventDropdown.Items, app.SolventDropdown.Value));
                    if isempty(solventIdx) || solventIdx > length(ns)
                        solventIdx = 1;
                    end
                end
                
                % Calculate eta and n(z) for the SELECTED solvent for the profile plots
                eta_selected = app.calcEta(phi, n_poly, ns(solventIdx));
                n_z_selected = app.calcRefrIndex(eta_selected);
                
                % Get lambda data
                lambdaCols = startsWith(T.Properties.VariableNames, 'lambda', 'IgnoreCase', true);
                lambdaNames = T.Properties.VariableNames(lambdaCols);
                lambda_vals = table2array(T(idx, lambdaNames));
                
                % Pre-calculate all neff values using the infinite-domain weighting
                neff_all_solvents = zeros(size(ns));
                for j = 1:length(ns)
                    eta_j = app.calcEta(phi, n_poly, ns(j));
                    n_z_j = app.calcRefrIndex(eta_j);
                    neff_all_solvents(j) = app.calcNeffInfinite(n_z_j, z, H, L, ns(j));
                end
                
                c1 = [0.13 0.50 0.92];
                c2 = [0.88 0.48 0.02];
                c3 = [0.08 0.65 0.40];
                c4 = [0.65 0.20 0.85];
                
                % PLOT 1: Volume Fraction vs z (fastest)
                cla(app.UIAxes1);
                fill(app.UIAxes1, [z; flipud(z)], [phi; zeros(size(phi))], c1, 'FaceAlpha', 0.25, 'EdgeColor', 'none');
                hold(app.UIAxes1, 'on');
                plot(app.UIAxes1, z, phi, 'Color', c1, 'LineWidth', 2.8);
                hold(app.UIAxes1, 'off');
                grid(app.UIAxes1, 'on');
                app.UIAxes1.GridAlpha = 0.3;
                xlabel(app.UIAxes1, 'z (nm)', 'FontSize', 13); 
                ylabel(app.UIAxes1, 'φ(z)', 'FontSize', 13);
                title(app.UIAxes1, 'Volume Fraction Profile', 'Color', c1, 'FontWeight', 'bold', 'FontSize', 12);
                app.UIAxes1.XLim = [0 max(z)];
                app.UIAxes1.YLim = [0 max(phi)*1.1];
                
                % PLOT 2: Refractive Index vs z
                cla(app.UIAxes2);
                fill(app.UIAxes2, [z; flipud(z)], [n_z_selected; ones(size(n_z_selected))*min(n_z_selected)], c2, 'FaceAlpha', 0.25, 'EdgeColor', 'none');
                hold(app.UIAxes2, 'on');
                plot(app.UIAxes2, z, n_z_selected, 'Color', c2, 'LineWidth', 2.8);
                xline(app.UIAxes2, H, '--', 'Color', c3, 'LineWidth', 1.5, 'Label', 'H boundary');
                hold(app.UIAxes2, 'off');
                grid(app.UIAxes2, 'on');
                app.UIAxes2.GridAlpha = 0.3;
                xlabel(app.UIAxes2, 'z (nm)', 'FontSize', 13); 
                ylabel(app.UIAxes2, 'n(z)', 'FontSize', 13);
                title(app.UIAxes2, sprintf('Refractive Index Profile (Solvent %d)', solventIdx), 'Color', c2, 'FontWeight', 'bold', 'FontSize', 12);
                app.UIAxes2.XLim = [0 max(z)];
                minN = min(n_z_selected);
                maxN = max(n_z_selected);
                app.UIAxes2.YLim = [minN - 0.05*(maxN-minN), maxN + 0.05*(maxN-minN)];
                
                % PLOT 3: Lambda vs Solvent Refractive Index
                cla(app.UIAxes3);
                validIdx3 = ~(isnan(ns) | isnan(lambda_vals));
                if sum(validIdx3) >= 2
                    x_vals3 = ns(validIdx3);
                    y_vals3 = lambda_vals(validIdx3);
                    p3 = polyfit(x_vals3, y_vals3, 1);
                    x_line3 = linspace(min(x_vals3)-0.02, max(x_vals3)+0.02, 200);
                    y_line3 = polyval(p3, x_line3);
                    hold(app.UIAxes3, 'on');
                    plot(app.UIAxes3, x_line3, y_line3, 'Color', c3, 'LineWidth', 2.5, 'LineStyle', '-');
                    scatter(app.UIAxes3, x_vals3, y_vals3, 100, c3, 'filled', 'MarkerEdgeColor', [1 1 1], 'LineWidth', 2);
                    
                    % Add slope text
                    slope3 = p3(1);
                    text(app.UIAxes3, 0.05, 0.95, sprintf('Slope = %.2f', slope3), 'Units', 'normalized', ...
                        'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 11, 'FontWeight', 'bold', 'Color', c3);
                    hold(app.UIAxes3, 'off');
                    app.UIAxes3.XLim = [min(x_vals3)-0.05 max(x_vals3)+0.05];
                    minY3 = min(y_vals3);
                    maxY3 = max(y_vals3);
                    app.UIAxes3.YLim = [minY3 - 0.1*(maxY3-minY3), maxY3 + 0.1*(maxY3-minY3)];
                else
                    text(app.UIAxes3, 0.5, 0.5, 'Insufficient Data', 'HorizontalAlignment', 'center', 'Units', 'normalized', 'FontSize', 10);
                end
                grid(app.UIAxes3, 'on');
                app.UIAxes3.GridAlpha = 0.3;
                xlabel(app.UIAxes3, 'n_{solv}', 'FontSize', 13, 'Interpreter', 'tex'); 
                ylabel(app.UIAxes3, '\lambda_{max} (nm)', 'FontSize', 13, 'Interpreter', 'tex');
                title(app.UIAxes3, 'Lambda vs Solvent', 'Color', c3, 'FontWeight', 'bold', 'FontSize', 12);
                
                % PLOT 4: Lambda vs Effective Refractive Index
                cla(app.UIAxes4);
                if ~isempty(app.neff_all) && idx <= length(app.neff_all) && ~isempty(app.neff_all{idx})
                    neff_data = app.neff_all{idx};
                    validIdx4 = ~(isnan(neff_data) | isnan(lambda_vals));
                    if sum(validIdx4) >= 2
                        x_vals4 = neff_data(validIdx4);
                        y_vals4 = lambda_vals(validIdx4);
                        p4 = polyfit(x_vals4, y_vals4, 1);
                        x_line4 = linspace(min(x_vals4)-0.02, max(x_vals4)+0.02, 200);
                        y_line4 = polyval(p4, x_line4);
                        hold(app.UIAxes4, 'on');
                        plot(app.UIAxes4, x_line4, y_line4, 'Color', c4, 'LineWidth', 2.5);
                        scatter(app.UIAxes4, x_vals4, y_vals4, 120, c4, 'filled', 'MarkerEdgeColor', [1 1 1], 'LineWidth', 2);
                        
                        % Add slope text
                        slope4 = p4(1);
                        text(app.UIAxes4, 0.05, 0.95, sprintf('Slope = %.2f', slope4), 'Units', 'normalized', ...
                            'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 11, 'FontWeight', 'bold', 'Color', c4);
                        hold(app.UIAxes4, 'off');
                    else
                        text(app.UIAxes4, 0.5, 0.5, 'Insufficient Data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
                    end
                else
                    text(app.UIAxes4, 0.5, 0.5, 'No neff Data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
                end
                grid(app.UIAxes4, 'on');
                app.UIAxes4.GridAlpha = 0.3;
                xlabel(app.UIAxes4, 'n_{eff}', 'FontSize', 13, 'Interpreter', 'tex'); 
                ylabel(app.UIAxes4, '\lambda_{max} (nm)', 'FontSize', 13, 'Interpreter', 'tex');
                title(app.UIAxes4, 'Lambda vs Effective', 'Color', c4, 'FontWeight', 'bold', 'FontSize', 12);
                
            catch ME
                app.addLog(['Plot error: ' ME.message]);
            end
        end
        
        function datasetChangedCallback(app)
            % Only update plots if data is loaded and solver has been run
            if ~isempty(app.resultTable)
                % Log the dataset change
                idx = str2double(app.DatasetDropdown.Value);
                app.addLog(sprintf('📊 Loading Dataset %d plots...', idx));
                
                % Disable dataset and solvent selection during plot update
                app.DatasetDropdown.Enable = 'off';
                app.SolventDropdown.Enable = 'off';
                
                % Gray out the dropdowns
                app.DatasetDropdown.BackgroundColor = [0.85 0.85 0.85];
                app.SolventDropdown.BackgroundColor = [0.85 0.85 0.85];
                
                drawnow;
                
                app.updatePlots();
                
                % Re-enable after plots are done
                app.DatasetDropdown.Enable = 'on';
                app.SolventDropdown.Enable = 'on';
                
                % Restore original colors
                app.DatasetDropdown.BackgroundColor = [1 1 1];
                app.SolventDropdown.BackgroundColor = [1 1 1];
                
                app.addLog(sprintf('✓ Dataset %d plots ready', idx));
                drawnow;
            end
        end
        
        function solventChangedCallback(app)
            % Log the solvent change
            solventStr = app.SolventDropdown.Value;
            app.addLog(sprintf('🧪 Updating plots for %s...', solventStr));
            
            % Disable dataset and solvent selection during plot update
            app.DatasetDropdown.Enable = 'off';
            app.SolventDropdown.Enable = 'off';
            
            % Gray out the dropdowns
            app.DatasetDropdown.BackgroundColor = [0.85 0.85 0.85];
            app.SolventDropdown.BackgroundColor = [0.85 0.85 0.85];
            
            drawnow;
            
            app.updatePlots();
            
            % Re-enable after plots are done
            app.DatasetDropdown.Enable = 'on';
            app.SolventDropdown.Enable = 'on';
            
            % Restore original colors
            app.DatasetDropdown.BackgroundColor = [1 1 1];
            app.SolventDropdown.BackgroundColor = [1 1 1];
            
            app.addLog(sprintf('✓ Plot updated for %s', solventStr));
            drawnow;
        end
        
        function exportCallback(app)
            if isempty(app.exportTable) && isempty(app.resultTable)
                app.addLog('Run solver first - nothing to export');
                return;
            end
            
            % Ask user where to save file
            [file, path] = uiputfile('*.xlsx', 'Save Export File');
            if isequal(file, 0), return; end
            
            % Bring app window to focus
            figure(app.UIFigure);
            
            fullPath = fullfile(path, file);
            
            % DISABLE ALL BUTTONS DURING EXPORT
            app.disableAllButtons();
            
            try
                % Prepare all sheets data
                sheetNames = {};
                sheetData = {};
                sheetIdx = 1;
                
                % Sheet 1: Main Results
                if ~isempty(app.exportTable)
                    sheetNames{sheetIdx} = 'Results';
                    sheetData{sheetIdx} = app.exportTable;
                    sheetIdx = sheetIdx + 1;
                end
                
                % Sheet 2: Solver Parameters
                paramNames = {'Radius of Nanoparticles (nm)', 'Decay Length L (nm)', 'Effective Polymer Segment Diameter b (nm)', ...
                    'Refractive Index of Polymer', 'Target Slope', 'Tolerance', 'dz (nm)', 'Max Iterations'};
                paramValues = [];
                for i = 1:8
                    paramValues = [paramValues; app.ParamFields{i}.Value];
                end
                paramData = table(paramNames(:), paramValues, 'VariableNames', {'Parameter', 'Value'});
                sheetNames{sheetIdx} = 'Parameters';
                sheetData{sheetIdx} = paramData;
                sheetIdx = sheetIdx + 1;
                
                % Sheet 3: Solvents
                if ~isempty(app.solvents)
                    solventData = array2table(app.solvents, 'VariableNames', cellfun(@(x) sprintf('n_solv_%d', x), num2cell(1:length(app.solvents)), 'UniformOutput', false));
                    sheetNames{sheetIdx} = 'Solvents';
                    sheetData{sheetIdx} = solventData;
                    sheetIdx = sheetIdx + 1;
                end
                
                % Sheets for Plot Data (one per dataset)
                if ~isempty(app.resultTable)
                    nDatasets = height(app.dataTable);
                    T = app.dataTable;
                    
                    for datasetIdx = 1:nDatasets
                        % Get lambda values
                        lambdaCols = startsWith(T.Properties.VariableNames, 'lambda', 'IgnoreCase', true);
                        lambdaNames = T.Properties.VariableNames(lambdaCols);
                        lambda_vals = table2array(T(datasetIdx, lambdaNames));
                        
                        ns = app.solvents;
                        
                        % Create plot data table with X and Y data
                        plotData = table(ns(:), lambda_vals(:), 'VariableNames', {'n_solvent', 'lambda'});
                        
                        % Add neff values
                        if ~isempty(app.neff_all) && datasetIdx <= length(app.neff_all) && ~isempty(app.neff_all{datasetIdx})
                            plotData.neff = app.neff_all{datasetIdx}(:);
                        end
                        
                        sheetNames{sheetIdx} = sprintf('Dataset_%d_PlotData', datasetIdx);
                        sheetData{sheetIdx} = plotData;
                        sheetIdx = sheetIdx + 1;
                    end
                end
                
                % Sheets for Profile Data (one per dataset)
                if ~isempty(app.resultTable)
                    nDatasets = height(app.dataTable);
                    T = app.dataTable;
                    
                    for datasetIdx = 1:nDatasets
                        H = T.H_nm(datasetIdx);
                        dz = app.ParamFields{7}.Value;
                        z = app.makeZGrid(H, dz);
                        
                        Rc = app.ParamFields{1}.Value;
                        L = app.ParamFields{2}.Value;
                        b = app.ParamFields{3}.Value;
                        n_poly = app.ParamFields{4}.Value;
                        ns = app.solvents;
                        
                        % Calculate volume fraction
                        GD_idx = app.GD_solved(datasetIdx);
                        phi = app.calcVolumeFraction(GD_idx, z, Rc, b, H);
                        
                        % Create profile data
                        profileData = table(z);
                        profileData.phi = phi;
                        
                        % Add refractive index for each solvent
                        for j = 1:length(ns)
                            eta_j = app.calcEta(phi, n_poly, ns(j));
                            n_z_j = app.calcRefrIndex(eta_j);
                            profileData.(sprintf('n_z_solvent_%d', j)) = n_z_j;
                        end
                        
                        sheetNames{sheetIdx} = sprintf('Dataset_%d_Profiles', datasetIdx);
                        sheetData{sheetIdx} = profileData;
                        sheetIdx = sheetIdx + 1;
                    end
                end
                
                % Write all sheets to Excel file - use fastest method
                if isfile(fullPath)
                    delete(fullPath);
                end
                
                app.addLog('⏳ Exporting to Excel...');
                tic;  % Start timer
                drawnow;
                
                totalSheets = length(sheetNames);
                
                % Write all sheets efficiently with single progress bar
                for i = 1:totalSheets
                    % Write the sheet
                    writetable(sheetData{i}, fullPath, 'Sheet', sheetNames{i});
                    
                    % Calculate progress percentage
                    progress = round(i / totalSheets * 100);
                    
                    % Create progress bar
                    barLength = 25;
                    filledLength = round(barLength * progress / 100);
                    bar = [repmat('█', 1, filledLength) repmat('░', 1, barLength - filledLength)];
                    
                    % Show single updating progress line
                    progressMsg = sprintf('   %s %d%% [%d/%d sheets]', bar, progress, i, totalSheets);
                    
                    % Remove previous progress line and add new one
                    current = app.LogTextArea.Value;
                    if ~isempty(current) && contains(current{end}, '█') && contains(current{end}, '%')
                        % Replace last line if it's a progress bar
                        current = current(1:end-1);
                    end
                    app.LogTextArea.Value = [current; {progressMsg}];
                    drawnow;
                end
                
                elapsed = toc;  % Get elapsed time
                app.addLog(sprintf('✅ DONE! Exported %d sheets in %.2f seconds', length(sheetNames), elapsed));
                app.addLog(sprintf('📁 File: %s', file));
                
            catch ME
                % Check if it's a file access error
                if contains(ME.message, 'permission') || contains(ME.message, 'open') || contains(ME.message, 'write')
                    app.addLog('❌ ERROR: File cannot be written!');
                    app.addLog('   Possible causes:');
                    app.addLog('   1. File is open in Excel or another application');
                    app.addLog('   2. No write permissions to the folder');
                    app.addLog('   3. File is read-only');
                    app.addLog('   Solution: Close the file and try again');
                else
                    app.addLog(['Export error: ' ME.message]);
                end
            end
            
            % RE-ENABLE ALL BUTTONS AFTER EXPORT
            app.enableAllButtons();
        end
        
        function clearCallback(app)
            app.dataTable = table();
            app.solvents = [];
            app.resultTable = table();
            app.GD_solved = [];
            app.slope_neff = [];
            app.R2_neff = [];
            app.neff_all = {};
            
            app.DataTable.Data = [];
            app.SolventsTable.Data = [];
            app.ResultsTable.Data = [];
            
            app.DataStatusLabel.Text = 'No file';
            app.DataStatusLabel.FontColor = [0.7 0.7 0.7];
            app.SolventsStatusLabel.Text = 'No file';
            app.SolventsStatusLabel.FontColor = [0.7 0.7 0.7];
            
            app.DatasetDropdown.Items = {};
            
            cla(app.UIAxes1); cla(app.UIAxes2); cla(app.UIAxes3); cla(app.UIAxes4);
            
            % Clear log properly
            app.LogTextArea.Value = '';
            app.addLog('✓ All data cleared');
        end
        
        function [GD, fitData, neff] = solveGD(app, z, Rc, b, H, L, n_poly, ns, lambdaData, targetSlope, tol, maxIter)
            % CORRECT CALCULATION FROM PREVIOUS VERSION
            objFcn = @(g) app.calcSlopeError(g, z, Rc, b, H, L, n_poly, ns, lambdaData, targetSlope);
            
            % Bracket search
            lo = 0;
            hi = max(1e-3, 0.01);
            flo = objFcn(lo);
            fhi = objFcn(hi);
            
            k = 0;
            while sign(flo) == sign(fhi) && k < 60
                hi = hi * 2 + 1e-4;
                fhi = objFcn(hi);
                k = k + 1;
            end
            
            if sign(flo) == sign(fhi)
                GD = hi;
            else
                opts = optimset('TolX', tol, 'MaxIter', min(maxIter, 5000), 'Display', 'off');
                GD = fzero(objFcn, [lo hi], opts);
                GD = max(GD, 0);
            end
            
            % Calculate neff over 0 to infinity and fit
            phi = app.calcVolumeFraction(GD, z, Rc, b, H);
            eta = app.calcEta(phi, n_poly, ns);
            n_z = app.calcRefrIndex(eta);
            neff = app.calcNeffInfinite(n_z, z, H, L, ns);
            
            % neff contains one effective refractive index value per solvent
            fitData = app.linearFit(neff, lambdaData);
        end
        
        function err = calcSlopeError(app, g, z, Rc, b, H, L, n_poly, ns, lambdaData, targetSlope)
            phi = app.calcVolumeFraction(max(g, 0), z, Rc, b, H);
            eta = app.calcEta(phi, n_poly, ns);
            n_z = app.calcRefrIndex(eta);
            neff = app.calcNeffInfinite(n_z, z, H, L, ns);
            fit = app.linearFit(neff, lambdaData);
            err = fit.slope - targetSlope;
        end
        
        function phi = calcVolumeFraction(~, g, z, Rc, b, H)
            dVpoly_dz = 4 * g * pi^2 * (b/2)^2 * Rc^2;
            dVshell_dz = 4 * pi * (Rc + z).^2;
            phi = dVpoly_dz ./ dVshell_dz;
            phi = min(max(phi, 0), 1);
            phi(z > H) = 0;
        end
        
        function eta = calcEta(~, phi, n_poly, ns)
            eta_poly = (n_poly^2 - 1) / (n_poly^2 + 2);
            eta_solv = (ns.^2 - 1) ./ (ns.^2 + 2);
            eta = phi .* eta_poly + (1 - phi) .* eta_solv;
        end
        
        function n_z = calcRefrIndex(~, eta)
            n_z = sqrt(1 + 2*eta) ./ sqrt(1 - eta);
        end
        
        function neff = calcNeffInfinite(~, n_z, z, H, L, ns)
            % Correct normalized near-field weighting over 0 <= z < infinity:
            %   w(z) = (2/L) exp(-2z/L)
            %
            % Inside the polymer shell (0 <= z <= H), n(z) is obtained
            % from the Lorentz-Lorenz polymer/solvent mixture. Beyond H,
            % the local refractive index is pure solvent. The solvent-tail
            % contribution from H to infinity is evaluated analytically.
            
            z = z(:);
            w = (2/L) .* exp(-2*z/L);
            
            if numel(z) == 1
                insideTerm = zeros(1, numel(ns));
            else
                insideTerm = trapz(z, n_z .* w);
            end
            
            solventTail = ns .* exp(-2*H/L);
            neff = insideTerm + solventTail;
        end
        
        function z = makeZGrid(~, H, dz)
            % Create a numerical grid that contains exactly z = H.
            if H <= 0
                z = 0;
                return;
            end
            
            z = (0:dz:H)';
            
            if z(end) < H
                z = [z; H];
            end
        end
        
        function fit = linearFit(~, x, y)
            x = x(:); y = y(:);
            valid = ~(isnan(x) | isnan(y));
            x = x(valid); y = y(valid);
            
            if length(x) < 2
                fit.slope = NaN; fit.icept = NaN; fit.R2 = NaN;
            else
                p = polyfit(x, y, 1);
                yFit = polyval(p, x);
                SSres = sum((y-yFit).^2);
                SStot = sum((y-mean(y)).^2);
                
                fit.slope = p(1);
                fit.icept = p(2);
                fit.R2 = 1 - SSres/SStot;
            end
        end
        
        function createUI(app)
            screenSize = get(0, 'ScreenSize');
            W = screenSize(3);
            H = screenSize(4);
            
            app.UIFigure = uifigure('Name', 'GraftCal', ...
                'NumberTitle', 'off', 'WindowState', 'maximized');
            app.UIFigure.Position = [1 1 W H];
            app.UIFigure.Color = app.colorLightGray;
            
            % ===== TOP BAR WITH TITLE AND BUTTONS =====
            btnH = 70;
            app.ButtonPanel = uipanel(app.UIFigure, ...
                'Position', [0 H-btnH W btnH], ...
                'BackgroundColor', app.colorDarkBlue, 'BorderType', 'none');
            
            % App Title
            app.AppTitleLabel = uilabel(app.ButtonPanel, ...
                'Position', [20 10 300 50], ...
                'Text', '▌ GraftCal', ...
                'FontSize', 24, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1]);
            
            % Button Layout
            btnW = 130;
            btnY = 12;
            btnStartX = 380;
            btnSpacing = 145;
            
            % Import Data Button
            app.ImportDataBtn = uibutton(app.ButtonPanel, 'push', ...
                'Position', [btnStartX btnY btnW 45], 'Text', '📂 Data', ...
                'BackgroundColor', app.colorBlue, 'FontColor', [1 1 1], ...
                'FontSize', 11, 'FontWeight', 'bold');
            app.ImportDataBtn.ButtonPushedFcn = @(~,~) app.importDataCallback();
            
            % Import Solvents Button
            app.ImportSolventsBtn = uibutton(app.ButtonPanel, 'push', ...
                'Position', [btnStartX+btnSpacing btnY btnW 45], 'Text', '🧪 Solvents', ...
                'BackgroundColor', app.colorGreen, 'FontColor', [1 1 1], ...
                'FontSize', 11, 'FontWeight', 'bold');
            app.ImportSolventsBtn.ButtonPushedFcn = @(~,~) app.importSolventsCallback();
            
            % Run Solver Button
            app.RunSolverBtn = uibutton(app.ButtonPanel, 'push', ...
                'Position', [btnStartX+2*btnSpacing btnY btnW 45], 'Text', '⚙️ Solve', ...
                'BackgroundColor', app.colorOrange, 'FontColor', [1 1 1], ...
                'FontSize', 11, 'FontWeight', 'bold');
            app.RunSolverBtn.ButtonPushedFcn = @(~,~) app.runSolverCallback();
            
            % Export Button
            app.ExportBtn = uibutton(app.ButtonPanel, 'push', ...
                'Position', [btnStartX+3*btnSpacing btnY btnW 45], 'Text', '💾 Export', ...
                'BackgroundColor', app.colorPurple, 'FontColor', [1 1 1], ...
                'FontSize', 11, 'FontWeight', 'bold');
            app.ExportBtn.ButtonPushedFcn = @(~,~) app.exportCallback();
            
            % Clear Button
            app.ClearBtn = uibutton(app.ButtonPanel, 'push', ...
                'Position', [btnStartX+4*btnSpacing btnY btnW 45], 'Text', '🔄 Clear', ...
                'BackgroundColor', app.colorGray, 'FontColor', [1 1 1], ...
                'FontSize', 11, 'FontWeight', 'bold');
            app.ClearBtn.ButtonPushedFcn = @(~,~) app.clearCallback();
            
            % ===== THREE-COLUMN LAYOUT (ALL ALIGNED FROM TOP) =====
            bodyH = H - btnH - 10;
            bodyY = 10;
            pad = 10;
            
            % Column widths
            colW1 = round(W * 0.28);  % Left (Data + Solvents + Log)
            colW2 = round(W * 0.18);  % Middle (Parameters)
            colW3 = W - colW1 - colW2 - pad*4;  % Right (Results + Plots)
            
            % ===== COLUMN 1: DATA (Shorter), SOLVENTS, and LOG =====
            app.LeftPanel = uipanel(app.UIFigure, ...
                'Position', [pad bodyY colW1 bodyH], ...
                'BorderType', 'none', 'BackgroundColor', app.colorLightGray);
            
            % Small padding between panels
            panelPad = 8;
            
            % Calculate panel heights accounting for padding - must sum to bodyH
            totalPad = panelPad * 2;  % 2 gaps between 3 panels
            availableH = bodyH - totalPad;
            dataH = availableH * 0.45;      % Data 45%
            solvH = availableH * 0.20;      % Solvents 20%
            logH = availableH * 0.35;       % Log 35%
            
            % Data Panel (45% at top - larger)
            app.DataPanel = uipanel(app.LeftPanel, ...
                'Position', [0 solvH+logH+panelPad*2 colW1 dataH], ...
                'BorderType', 'line', 'BorderWidth', 2.5, 'ForegroundColor', app.colorBlue, ...
                'BackgroundColor', [0.92 0.95 1.00]);
            app.DataTitleLabel = uilabel(app.DataPanel, 'Position', [15 dataH-35 colW1-30 20], ...
                'Text', '📊 Data', 'FontSize', 13, 'FontWeight', 'bold', 'FontColor', app.colorText);
            app.DataStatusLabel = uilabel(app.DataPanel, 'Position', [15 dataH-55 colW1-30 18], ...
                'Text', 'No file', 'FontSize', 11, 'FontColor', [0.7 0.7 0.7]);
            app.DataTable = uitable(app.DataPanel, 'Position', [10 10 colW1-20 dataH-70], ...
                'ColumnEditable', false, 'FontSize', 11, ...
                'BackgroundColor', [1 1 1; 0.96 0.98 1.00], 'ForegroundColor', app.colorText);
            
            % Solvents Panel (30% in middle)
            app.SolventsPanel = uipanel(app.LeftPanel, ...
                'Position', [0 logH+panelPad colW1 solvH], ...
                'BorderType', 'line', 'BorderWidth', 2.5, 'ForegroundColor', app.colorGreen, ...
                'BackgroundColor', [0.90 0.98 0.94]);
            app.SolventsTitleLabel = uilabel(app.SolventsPanel, 'Position', [15 solvH-35 colW1-30 20], ...
                'Text', '🧪 Solvents', 'FontSize', 13, 'FontWeight', 'bold', 'FontColor', app.colorText);
            app.SolventsStatusLabel = uilabel(app.SolventsPanel, 'Position', [15 solvH-55 colW1-30 18], ...
                'Text', 'No file', 'FontSize', 11, 'FontColor', [0.7 0.7 0.7]);
            app.SolventsTable = uitable(app.SolventsPanel, 'Position', [10 10 colW1-20 max(30, solvH-70)], ...
                'ColumnEditable', false, 'FontSize', 11, ...
                'BackgroundColor', [1 1 1; 0.96 0.98 1.00], 'ForegroundColor', app.colorText);
            
            % Log Panel (25% at bottom)
            app.LogPanel = uipanel(app.LeftPanel, ...
                'Position', [0 0 colW1 logH], ...
                'BorderType', 'line', 'BorderWidth', 2.5, 'ForegroundColor', [0.25 0.35 0.55], ...
                'BackgroundColor', [0.08 0.10 0.16]);
            app.LogTitleLabel = uilabel(app.LogPanel, 'Position', [15 logH-28 colW1-30 18], ...
                'Text', '📋 Log', 'FontSize', 12, 'FontWeight', 'bold', 'FontColor', [0.30 0.85 0.50]);
            app.LogTextArea = uitextarea(app.LogPanel, 'Position', [10 10 colW1-20 logH-45], ...
                'FontSize', 11, 'FontName', 'Consolas', 'FontColor', [0.25 0.90 0.55], ...
                'BackgroundColor', [0.08 0.10 0.16], 'Editable', false, 'WordWrap', true);
            
            % ===== COLUMN 2: PARAMETERS =====
            app.MiddlePanel = uipanel(app.UIFigure, ...
                'Position', [pad+colW1+pad bodyY colW2 bodyH], ...
                'BorderType', 'none', 'BackgroundColor', app.colorLightGray);
            
            app.ParametersPanel = uipanel(app.MiddlePanel, 'Position', [0 0 colW2 bodyH], ...
                'BorderType', 'line', 'BorderWidth', 2.5, 'ForegroundColor', app.colorOrange, ...
                'BackgroundColor', [1.00 0.96 0.88]);
            
            app.ParamTitleLabel = uilabel(app.ParametersPanel, 'Position', [12 bodyH-35 colW2-24 20], ...
                'Text', '⚙️ Parameters', 'FontSize', 13, 'FontWeight', 'bold', 'FontColor', app.colorText);
            
            paramNames = {'Radius of Nanoparticles (nm)', 'Decay Length L (nm)', 'Effective Polymer Segment Diameter b (nm)', 'Refractive Index of Polymer', 'Target Slope', 'Tolerance', 'dz (nm)', 'Max Iterations'};
            app.ParamLabels = cell(8, 1);
            app.ParamFields = cell(8, 1);
            
            slotH = (bodyH - 50) / 8;
            
            for i = 1:8
                yPos = bodyH - 50 - (i-1)*slotH;
                app.ParamLabels{i} = uilabel(app.ParametersPanel, ...
                    'Position', [12 yPos-18 colW2-24 13], 'Text', paramNames{i}, ...
                    'FontSize', 10, 'FontWeight', 'bold', 'FontColor', app.colorText);
                app.ParamFields{i} = uieditfield(app.ParametersPanel, 'numeric', ...
                    'Position', [12 yPos-40 colW2-24 18], 'FontSize', 11, ...
                    'FontColor', app.colorText, 'BackgroundColor', [1 1 1]);
            end
            
            % ===== COLUMN 3: RESULTS + PLOTS =====
            col3X = pad + colW1 + pad + colW2 + pad;
            
            app.RightPanel = uipanel(app.UIFigure, ...
                'Position', [col3X bodyY colW3 bodyH], ...
                'BorderType', 'none', 'BackgroundColor', app.colorLightGray);
            
            resH = round(bodyH * 0.22);
            app.ResultsPanel = uipanel(app.RightPanel, ...
                'Position', [0 bodyH-resH colW3 resH], ...
                'BorderType', 'line', 'BorderWidth', 2.5, 'ForegroundColor', app.colorGreen, ...
                'BackgroundColor', [0.90 0.98 0.94]);
            
            app.ResultsTitleLabel = uilabel(app.ResultsPanel, 'Position', [15 resH-28 colW3-30 18], ...
                'Text', '📈 Results', 'FontSize', 12, 'FontWeight', 'bold', 'FontColor', app.colorText);
            
            app.DatasetLabel = uilabel(app.ResultsPanel, 'Position', [15 resH-55 80 16], ...
                'Text', 'Dataset:', 'FontSize', 11, 'FontWeight', 'bold', 'FontColor', app.colorText);
            
            app.DatasetDropdown = uidropdown(app.ResultsPanel, ...
                'Position', [100 resH-58 colW3-120 22], 'FontSize', 11, ...
                'BackgroundColor', [1 1 1], 'FontColor', app.colorText);
            app.DatasetDropdown.ValueChangedFcn = @(~,~) app.datasetChangedCallback();
            
            app.ResultsTable = uitable(app.ResultsPanel, ...
                'Position', [10 10 colW3-20 resH-70], 'ColumnEditable', false, 'FontSize', 11, ...
                'BackgroundColor', [1 1 1; 0.96 0.98 1.00], 'ForegroundColor', app.colorText);
            
            % Plots Panel
            plotH = bodyH - resH - pad;
            app.PlotsPanel = uipanel(app.RightPanel, ...
                'Position', [0 0 colW3 plotH], ...
                'BorderType', 'line', 'BorderWidth', 2.5, 'ForegroundColor', app.colorOrange, ...
                'BackgroundColor', [1.00 0.99 0.97]);
            
            app.PlotsTitleLabel = uilabel(app.PlotsPanel, 'Position', [15 plotH-28 colW3-30 18], ...
                'Text', '📊 Plots', 'FontSize', 12, 'FontWeight', 'bold', 'FontColor', app.colorText);
            
            app.SolventLabel = uilabel(app.PlotsPanel, 'Position', [15 plotH-55 100 16], ...
                'Text', 'Solvent:', 'FontSize', 11, 'FontWeight', 'bold', 'FontColor', app.colorText);
            
            app.SolventDropdown = uidropdown(app.PlotsPanel, ...
                'Position', [125 plotH-58 colW3-150 22], 'FontSize', 11, ...
                'BackgroundColor', [1 1 1], 'FontColor', app.colorText);
            app.SolventDropdown.ValueChangedFcn = @(~,~) app.solventChangedCallback();
            
            axW = (colW3 - 30) / 2;
            axH = (plotH - 75) / 2;
            
            app.UIAxes1 = uiaxes(app.PlotsPanel, 'Position', [15 plotH/2-20 axW axH-5]);
            app.UIAxes2 = uiaxes(app.PlotsPanel, 'Position', [15+axW+5 plotH/2-20 axW axH-5]);
            app.UIAxes3 = uiaxes(app.PlotsPanel, 'Position', [15 15 axW axH-5]);
            app.UIAxes4 = uiaxes(app.PlotsPanel, 'Position', [15+axW+5 15 axW axH-5]);
            
            for ax = [app.UIAxes1, app.UIAxes2, app.UIAxes3, app.UIAxes4]
                ax.Color = [1 1 1];
                ax.BackgroundColor = [1 1 1];
                ax.Box = 'on';
                ax.FontSize = 11;
                ax.XColor = [0.35 0.35 0.35];
                ax.YColor = [0.35 0.35 0.35];
                ax.GridColor = [0.85 0.85 0.85];
            end
        end
    end
end