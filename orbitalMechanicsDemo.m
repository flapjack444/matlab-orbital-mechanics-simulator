function orbitalMechanicsDemo
% ORBITALMECHANICSDEMO  Interactive two-body Earth-orbit demonstration.
%
% HOW TO RUN
% ----------
% 1. Save this file as: orbitalMechanicsDemo.m
% 2. Put it on the MATLAB path / in the Current Folder.
% 3. Run from the Command Window:
%       orbitalMechanicsDemo
%
% No Aerospace Toolbox is required. The model uses classical Keplerian
% two-body propagation about a spherical Earth.
%
% Physics constants:
%   Earth radius Re = 6371 km
%   Earth mu        = 398600.4418 km^3/s^2
%
% Notes:
% - Elliptic orbits only: 0 <= e < 1.
% - To keep the demonstration physically meaningful, eccentricity is
%   automatically limited so periapsis stays at least 120 km above Earth.
% - For circular/equatorial cases, RAAN and argument of periapsis are kept
%   as user-defined orientation angles even though classical elements are
%   formally singular there. The state conversion remains numerically safe.

%% Constants and initial application state
mu = 398600.4418;       % km^3/s^2
Re = 6371.0;            % km
minPeriAlt = 120.0;     % km, safety clamp for this demo

defaults = struct( ...
    'a', Re + 420, ...
    'e', 0.0005, ...
    'inc', 51.64, ...
    'raan', 0.0, ...
    'argp', 0.0, ...
    'nu0', 0.0, ...
    'speed', 250.0);

app = struct();
app.params = defaults;
app.simTime = 0.0;
app.timerPeriod = 0.04; % wall-clock seconds between updates
app.isRunning = false;
app.isInternalUpdate = false;

%% Build the GUI
app.fig = uifigure( ...
    'Name','Interactive Two-Body Orbital Mechanics Demo', ...
    'Position',[40 40 1500 900], ...
    'Color',[0.055 0.065 0.085], ...
    'CloseRequestFcn',@onClose);

mainGrid = uigridlayout(app.fig,[1 2]);
mainGrid.ColumnWidth = {'3x','1.35x'};
mainGrid.RowHeight = {'1x'};
mainGrid.Padding = [10 10 10 10];
mainGrid.ColumnSpacing = 10;

% Left: visualization
vizPanel = uipanel(mainGrid, ...
    'Title','3D ECI Visualization', ...
    'ForegroundColor',[0.92 0.94 0.98], ...
    'BackgroundColor',[0.075 0.085 0.11], ...
    'FontWeight','bold');

vizGrid = uigridlayout(vizPanel,[1 1]);
vizGrid.Padding = [4 4 4 4];
app.ax = uiaxes(vizGrid);
app.ax.Color = [0.025 0.03 0.045];
app.ax.XColor = [0.72 0.75 0.82];
app.ax.YColor = [0.72 0.75 0.82];
app.ax.ZColor = [0.72 0.75 0.82];
app.ax.GridColor = [0.28 0.32 0.40];
app.ax.MinorGridColor = [0.18 0.22 0.30];
app.ax.FontSize = 11;
app.ax.NextPlot = 'add';
app.ax.Box = 'on';
app.ax.XGrid = 'on';
app.ax.YGrid = 'on';
app.ax.ZGrid = 'on';
app.ax.DataAspectRatio = [1 1 1];
view(app.ax,35,24);
xlabel(app.ax,'ECI X (km)');
ylabel(app.ax,'ECI Y (km)');
zlabel(app.ax,'ECI Z (km)');
title(app.ax,'Earth-Centered Inertial Frame','Color',[0.95 0.96 1.0]);

% Right: controls and numerical readouts
controlPanel = uipanel(mainGrid, ...
    'Title','Orbit Controls and Live State', ...
    'ForegroundColor',[0.92 0.94 0.98], ...
    'BackgroundColor',[0.075 0.085 0.11], ...
    'FontWeight','bold');

cg = uigridlayout(controlPanel,[27 3]);
cg.ColumnWidth = {145,'1x',95};
cg.RowHeight = {28,27,27,27,27,27,27,27,25,32,32,38,30,24,24,24,24,24,24,24,24,24,24,24,24,24,'1x'};
cg.Padding = [8 8 8 8];
cg.RowSpacing = 3;
cg.ColumnSpacing = 7;

header = uilabel(cg, ...
    'Text','Keplerian Orbital Elements', ...
    'FontSize',15, ...
    'FontWeight','bold', ...
    'FontColor',[0.97 0.98 1.0], ...
    'HorizontalAlignment','center');
header.Layout.Row = 1;
header.Layout.Column = [1 3];

% Element controls
[app.aSlider, app.aEdit] = addControl(2,'Semi-major axis a (km)',[6671 43000],app.params.a,@onAChanged,'%.1f');
[app.eSlider, app.eEdit] = addControl(3,'Eccentricity e',[0 0.9],app.params.e,@onEChanged,'%.5f');
[app.iSlider, app.iEdit] = addControl(4,'Inclination i (deg)',[0 180],app.params.inc,@onIChanged,'%.2f');
[app.raanSlider, app.raanEdit] = addControl(5,'RAAN \Omega (deg)',[0 360],app.params.raan,@onRAANChanged,'%.2f');
[app.argpSlider, app.argpEdit] = addControl(6,'Arg. periapsis \omega (deg)',[0 360],app.params.argp,@onArgpChanged,'%.2f');
[app.nuSlider, app.nuEdit] = addControl(7,'Initial true anomaly \nu (deg)',[0 360],app.params.nu0,@onNuChanged,'%.2f');
[app.speedSlider, app.speedEdit] = addControl(8,'Animation speed (x)',[1 5000],app.params.speed,@onSpeedChanged,'%.0f');

% Display options
app.planeCheck = uicheckbox(cg, ...
    'Text','Show orbital plane', ...
    'Value',true, ...
    'FontColor',[0.88 0.90 0.95], ...
    'ValueChangedFcn',@(~,~)drawStaticScene());
app.planeCheck.Layout.Row = 9;
app.planeCheck.Layout.Column = [1 2];

app.markerCheck = uicheckbox(cg, ...
    'Text','Show apsides/nodes', ...
    'Value',true, ...
    'FontColor',[0.88 0.90 0.95], ...
    'ValueChangedFcn',@(~,~)drawStaticScene());
app.markerCheck.Layout.Row = 9;
app.markerCheck.Layout.Column = 3;

% Animation buttons
app.pauseButton = uibutton(cg,'push', ...
    'Text','Pause', ...
    'FontWeight','bold', ...
    'ButtonPushedFcn',@onPauseResume);
app.pauseButton.Layout.Row = 10;
app.pauseButton.Layout.Column = [1 2];

app.resetAnimButton = uibutton(cg,'push', ...
    'Text','Reset Animation', ...
    'ButtonPushedFcn',@onResetAnimation);
app.resetAnimButton.Layout.Row = 10;
app.resetAnimButton.Layout.Column = 3;

% Presets
app.issButton = uibutton(cg,'push', ...
    'Text','Reset to ISS-like Orbit', ...
    'ButtonPushedFcn',@(~,~)applyPreset('ISS'));
app.issButton.Layout.Row = 11;
app.issButton.Layout.Column = [1 2];

app.geoButton = uibutton(cg,'push', ...
    'Text','Reset to GEO', ...
    'ButtonPushedFcn',@(~,~)applyPreset('GEO'));
app.geoButton.Layout.Row = 11;
app.geoButton.Layout.Column = 3;

% Status line
app.statusLabel = uilabel(cg, ...
    'Text','Ready. Element edits redefine the propagation epoch.', ...
    'WordWrap','on', ...
    'FontColor',[0.65 0.82 1.0], ...
    'FontSize',11);
app.statusLabel.Layout.Row = 12;
app.statusLabel.Layout.Column = [1 3];

readHeader = uilabel(cg, ...
    'Text','Real-Time Calculated Values', ...
    'FontSize',14, ...
    'FontWeight','bold', ...
    'FontColor',[0.97 0.98 1.0], ...
    'HorizontalAlignment','center');
readHeader.Layout.Row = 13;
readHeader.Layout.Column = [1 3];

% Readout labels
app.periodValue = addReadout(14,'Orbital period (hr)');
app.periValue   = addReadout(15,'Periapsis altitude (km)');
app.apoValue    = addReadout(16,'Apoapsis altitude (km)');
app.energyValue = addReadout(17,'Specific energy (km^2/s^2)');
app.hValue      = addReadout(18,'Specific ang. momentum (km^2/s)');
app.xValue      = addReadout(19,'ECI X (km)');
app.yValue      = addReadout(20,'ECI Y (km)');
app.zValue      = addReadout(21,'ECI Z (km)');
app.vValue      = addReadout(22,'Velocity magnitude (km/s)');
app.EValue      = addReadout(23,'Eccentric anomaly E (deg)');
app.MValue      = addReadout(24,'Mean anomaly M (deg)');
app.nuValue     = addReadout(25,'True anomaly \nu (deg)');
app.timeValue   = addReadout(26,'Simulation time (s)');

footer = uilabel(cg, ...
    'Text','Two-body model only: no J2, drag, third-body gravity, or Earth rotation.', ...
    'WordWrap','on', ...
    'FontColor',[0.57 0.61 0.69], ...
    'FontAngle','italic', ...
    'FontSize',10, ...
    'VerticalAlignment','bottom');
footer.Layout.Row = 27;
footer.Layout.Column = [1 3];

%% Create timer and initialize visualization
app.animTimer = timer( ...
    'ExecutionMode','fixedSpacing', ...
    'Period',app.timerPeriod, ...
    'BusyMode','drop', ...
    'TimerFcn',@onTimerTick, ...
    'ErrorFcn',@onTimerError);

sanitizeAndSync('initial');
drawStaticScene();
updateDynamicState();

app.isRunning = true;
start(app.animTimer);

%% Nested UI helper functions
    function [slider, edit] = addControl(row,labelText,limits,value,callback,fmt)
        lab = uilabel(cg, ...
            'Text',labelText, ...
            'FontColor',[0.86 0.88 0.94], ...
            'HorizontalAlignment','left');
        lab.Layout.Row = row;
        lab.Layout.Column = 1;

        slider = uislider(cg, ...
            'Limits',limits, ...
            'Value',value, ...
            'MajorTicks',[], ...
            'ValueChangedFcn',callback, ...
            'ValueChangingFcn',callback);
        slider.Layout.Row = row;
        slider.Layout.Column = 2;

        edit = uieditfield(cg,'numeric', ...
            'Limits',limits, ...
            'Value',value, ...
            'ValueDisplayFormat',fmt, ...
            'BackgroundColor',[0.12 0.135 0.17], ...
            'FontColor',[0.95 0.96 1.0], ...
            'ValueChangedFcn',callback);
        edit.Layout.Row = row;
        edit.Layout.Column = 3;
    end

    function valueLabel = addReadout(row,labelText)
        lab = uilabel(cg, ...
            'Text',labelText, ...
            'FontColor',[0.73 0.76 0.83]);
        lab.Layout.Row = row;
        lab.Layout.Column = [1 2];

        valueLabel = uilabel(cg, ...
            'Text','--', ...
            'FontColor',[0.94 0.97 1.0], ...
            'FontWeight','bold', ...
            'HorizontalAlignment','right');
        valueLabel.Layout.Row = row;
        valueLabel.Layout.Column = 3;
    end

%% Control callbacks
    function onAChanged(src,evt)
        if app.isInternalUpdate, return; end
        app.params.a = eventValue(src,evt);
        sanitizeAndSync('a');
        resetEpochAndRedraw('Semi-major axis updated.');
    end

    function onEChanged(src,evt)
        if app.isInternalUpdate, return; end
        app.params.e = eventValue(src,evt);
        sanitizeAndSync('e');
        resetEpochAndRedraw('Eccentricity updated.');
    end

    function onIChanged(src,evt)
        if app.isInternalUpdate, return; end
        app.params.inc = eventValue(src,evt);
        sanitizeAndSync('i');
        resetEpochAndRedraw('Inclination updated.');
    end

    function onRAANChanged(src,evt)
        if app.isInternalUpdate, return; end
        app.params.raan = eventValue(src,evt);
        sanitizeAndSync('raan');
        resetEpochAndRedraw('RAAN updated.');
    end

    function onArgpChanged(src,evt)
        if app.isInternalUpdate, return; end
        app.params.argp = eventValue(src,evt);
        sanitizeAndSync('argp');
        resetEpochAndRedraw('Argument of periapsis updated.');
    end

    function onNuChanged(src,evt)
        if app.isInternalUpdate, return; end
        app.params.nu0 = eventValue(src,evt);
        sanitizeAndSync('nu');
        resetEpochAndRedraw('Initial anomaly updated.');
    end

    function onSpeedChanged(src,evt)
        if app.isInternalUpdate, return; end
        app.params.speed = max(1,min(5000,eventValue(src,evt)));
        syncControls();
        app.statusLabel.Text = sprintf('Animation speed set to %.0fx.',app.params.speed);
    end

    function v = eventValue(src,evt)
        % ValueChangingData has evt.Value; edit-field callbacks generally do not.
        if isprop(evt,'Value')
            v = evt.Value;
        else
            v = src.Value;
        end
    end

%% Animation callbacks
    function onTimerTick(~,~)
        if ~isvalid(app.fig) || ~app.isRunning
            return;
        end
        app.simTime = app.simTime + app.timerPeriod*app.params.speed;
        updateDynamicState();
        drawnow limitrate nocallbacks;
    end

    function onTimerError(~,~)
        app.isRunning = false;
        if isvalid(app.fig)
            app.pauseButton.Text = 'Resume';
            app.statusLabel.Text = 'Animation timer error. The animation has been paused.';
        end
    end

    function onPauseResume(~,~)
        if app.isRunning
            app.isRunning = false;
            if strcmp(app.animTimer.Running,'on')
                stop(app.animTimer);
            end
            app.pauseButton.Text = 'Resume';
            app.statusLabel.Text = 'Animation paused.';
        else
            app.isRunning = true;
            if strcmp(app.animTimer.Running,'off')
                start(app.animTimer);
            end
            app.pauseButton.Text = 'Pause';
            app.statusLabel.Text = 'Animation resumed.';
        end
    end

    function onResetAnimation(~,~)
        app.simTime = 0.0;
        updateDynamicState();
        app.statusLabel.Text = 'Animation phase reset to the selected initial true anomaly.';
    end

%% Presets and parameter handling
    function applyPreset(whichPreset)
        switch upper(whichPreset)
            case 'ISS'
                app.params.a = Re + 420;
                app.params.e = 0.0005;
                app.params.inc = 51.64;
                app.params.raan = 25.0;
                app.params.argp = 15.0;
                app.params.nu0 = 0.0;
                app.params.speed = 250;
                msg = 'ISS-like orbit loaded.';
            case 'GEO'
                app.params.a = 42164.0;
                app.params.e = 0.0;
                app.params.inc = 0.0;
                app.params.raan = 0.0;
                app.params.argp = 0.0;
                app.params.nu0 = 0.0;
                app.params.speed = 1500;
                msg = 'Geostationary-radius circular equatorial orbit loaded.';
            otherwise
                return;
        end

        sanitizeAndSync('preset');
        app.simTime = 0.0;
        drawStaticScene();
        updateDynamicState();
        app.statusLabel.Text = msg;
    end

    function sanitizeAndSync(sourceName)
        % Clamp the element set to the supported GUI/model domain.
        didClamp = false;
        app.params.a = max(6671,min(43000,app.params.a));
        app.params.e = max(0,min(0.9,app.params.e));
        app.params.inc = max(0,min(180,app.params.inc));
        app.params.raan = mod(app.params.raan,360);
        app.params.argp = mod(app.params.argp,360);
        app.params.nu0 = mod(app.params.nu0,360);
        app.params.speed = max(1,min(5000,app.params.speed));

        % Limit eccentricity so the osculating ellipse does not intersect Earth.
        maxEPhysical = 1 - (Re + minPeriAlt)/app.params.a;
        maxEPhysical = max(0,min(0.9,maxEPhysical));
        if app.params.e > maxEPhysical
            app.params.e = maxEPhysical;
            didClamp = true;
            if ~strcmp(sourceName,'initial')
                app.statusLabel.Text = sprintf( ...
                    'Eccentricity clamped to %.5f so periapsis remains at least %.0f km altitude.', ...
                    app.params.e,minPeriAlt);
            end
        end

        app.lastClampOccurred = didClamp;
        syncControls();
    end

    function syncControls()
        app.isInternalUpdate = true;
        cleanupObj = onCleanup(@()setInternalUpdateFalse()); %#ok<NASGU>

        app.aSlider.Value = app.params.a;
        app.aEdit.Value = app.params.a;
        app.eSlider.Value = app.params.e;
        app.eEdit.Value = app.params.e;
        app.iSlider.Value = app.params.inc;
        app.iEdit.Value = app.params.inc;
        app.raanSlider.Value = app.params.raan;
        app.raanEdit.Value = app.params.raan;
        app.argpSlider.Value = app.params.argp;
        app.argpEdit.Value = app.params.argp;
        app.nuSlider.Value = app.params.nu0;
        app.nuEdit.Value = app.params.nu0;
        app.speedSlider.Value = app.params.speed;
        app.speedEdit.Value = app.params.speed;
    end

    function setInternalUpdateFalse()
        app.isInternalUpdate = false;
    end

    function resetEpochAndRedraw(defaultMessage)
        app.simTime = 0.0;
        drawStaticScene();
        updateDynamicState();
        if ~isfield(app,'lastClampOccurred') || ~app.lastClampOccurred
            app.statusLabel.Text = defaultMessage;
        end
    end

%% Drawing functions
    function drawStaticScene()
        if ~isvalid(app.ax), return; end

        cla(app.ax);
        hold(app.ax,'on');

        % Earth sphere
        [xe,ye,ze] = sphere(72);
        surf(app.ax,Re*xe,Re*ye,Re*ze, ...
            'FaceColor',[0.06 0.28 0.72], ...
            'EdgeColor','none', ...
            'FaceAlpha',0.98, ...
            'AmbientStrength',0.30, ...
            'DiffuseStrength',0.70, ...
            'SpecularStrength',0.15);

        % Latitude lines
        lon = linspace(0,2*pi,181);
        for latDeg = -60:30:60
            lat = latDeg*pi/180;
            rr = Re*1.002;
            x = rr*cos(lat).*cos(lon);
            y = rr*cos(lat).*sin(lon);
            z = rr*sin(lat)*ones(size(lon));
            plot3(app.ax,x,y,z,'Color',[0.28 0.55 0.92],'LineWidth',0.55);
        end

        % Longitude lines
        lat = linspace(-pi/2,pi/2,121);
        for lonDeg = 0:30:150
            ll = lonDeg*pi/180;
            rr = Re*1.002;
            x = rr*cos(lat)*cos(ll);
            y = rr*cos(lat)*sin(ll);
            z = rr*sin(lat);
            plot3(app.ax,x,y,z,'Color',[0.28 0.55 0.92],'LineWidth',0.45);
        end

        % Equator emphasis
        plot3(app.ax,Re*1.004*cos(lon),Re*1.004*sin(lon),zeros(size(lon)), ...
            'Color',[0.35 0.85 1.0],'LineWidth',1.0);

        % Orbit geometry
        a = app.params.a;
        e = app.params.e;
        inc = app.params.inc*pi/180;
        raan = app.params.raan*pi/180;
        argp = app.params.argp*pi/180;
        R = rotateToECI(raan,inc,argp);

        Egrid = linspace(0,2*pi,900);
        rp = [a*(cos(Egrid)-e); ...
              a*sqrt(max(0,1-e^2))*sin(Egrid); ...
              zeros(size(Egrid))];
        rECI = R*rp;

        app.hOrbit = plot3(app.ax,rECI(1,:),rECI(2,:),rECI(3,:), ...
            'Color',[1.0 0.72 0.20], ...
            'LineWidth',2.0);

        % Optional orbital plane, drawn as a transparent disk in the same plane.
        if app.planeCheck.Value
            rPlane = min(a*(1+e)*1.08,50000);
            th = linspace(0,2*pi,180);
            diskPF = [rPlane*cos(th); rPlane*sin(th); zeros(size(th))];
            diskECI = R*diskPF;
            patch(app.ax,diskECI(1,:),diskECI(2,:),diskECI(3,:),[0.68 0.70 0.76], ...
                'FaceAlpha',0.055,'EdgeColor',[0.52 0.55 0.62], ...
                'EdgeAlpha',0.28,'LineWidth',0.7);
        end

        % Optional markers: periapsis, apoapsis, ascending/descending nodes.
        if app.markerCheck.Value
            [rPeri,~] = orbitalElements2State(mu,a,e,inc,raan,argp,0);
            [rApo,~]  = orbitalElements2State(mu,a,e,inc,raan,argp,pi);

            scatter3(app.ax,rPeri(1),rPeri(2),rPeri(3),55,[0.3 1.0 0.42],'filled');
            scatter3(app.ax,rApo(1),rApo(2),rApo(3),55,[1.0 0.35 0.35],'filled');
            text(app.ax,rPeri(1),rPeri(2),rPeri(3),'  Periapsis', ...
                'Color',[0.55 1.0 0.62],'FontSize',10);
            text(app.ax,rApo(1),rApo(2),rApo(3),'  Apoapsis', ...
                'Color',[1.0 0.58 0.58],'FontSize',10);

            if abs(sin(inc)) > 1e-8
                nuAsc = mod(-argp,2*pi);
                nuDesc = mod(pi-argp,2*pi);
                [rAsc,~] = orbitalElements2State(mu,a,e,inc,raan,argp,nuAsc);
                [rDesc,~] = orbitalElements2State(mu,a,e,inc,raan,argp,nuDesc);
                scatter3(app.ax,rAsc(1),rAsc(2),rAsc(3),42,[0.35 0.95 1.0],'filled');
                scatter3(app.ax,rDesc(1),rDesc(2),rDesc(3),42,[0.75 0.45 1.0],'filled');
                text(app.ax,rAsc(1),rAsc(2),rAsc(3),'  Asc. node', ...
                    'Color',[0.55 0.95 1.0],'FontSize',9);
                text(app.ax,rDesc(1),rDesc(2),rDesc(3),'  Desc. node', ...
                    'Color',[0.83 0.65 1.0],'FontSize',9);
            end
        end

        % Dynamic objects: satellite and radius vector
        app.hRadius = plot3(app.ax,[0 0],[0 0],[0 0], ...
            'Color',[0.75 0.78 0.88], ...
            'LineStyle','--', ...
            'LineWidth',0.8);
        app.hSat = scatter3(app.ax,0,0,0,95,[1 1 1],'filled', ...
            'MarkerEdgeColor',[0.1 0.1 0.1], ...
            'LineWidth',1.0);

        % ECI reference axes
        refLen = max(Re*1.45,min(a*(1+e)*0.22,12000));
        quiver3(app.ax,0,0,0,refLen,0,0,0,'Color',[0.95 0.32 0.32],'LineWidth',1.2,'MaxHeadSize',0.18);
        quiver3(app.ax,0,0,0,0,refLen,0,0,'Color',[0.32 0.95 0.45],'LineWidth',1.2,'MaxHeadSize',0.18);
        quiver3(app.ax,0,0,0,0,0,refLen,0,'Color',[0.36 0.62 1.0],'LineWidth',1.2,'MaxHeadSize',0.18);
        text(app.ax,refLen,0,0,' +X','Color',[1.0 0.45 0.45]);
        text(app.ax,0,refLen,0,' +Y','Color',[0.45 1.0 0.55]);
        text(app.ax,0,0,refLen,' +Z','Color',[0.52 0.72 1.0]);

        % Lighting
        camlight(app.ax,'headlight');
        lighting(app.ax,'gouraud');

        % Axis limits sized to the orbit.
        rMax = a*(1+e);
        lim = max(Re*1.35,rMax*1.12);
        xlim(app.ax,[-lim lim]);
        ylim(app.ax,[-lim lim]);
        zlim(app.ax,[-lim lim]);
        app.ax.DataAspectRatio = [1 1 1];
        view(app.ax,35,24);
        xlabel(app.ax,'ECI X (km)');
        ylabel(app.ax,'ECI Y (km)');
        zlabel(app.ax,'ECI Z (km)');
        title(app.ax,'Earth-Centered Inertial Frame','Color',[0.95 0.96 1.0]);
        grid(app.ax,'on');
        hold(app.ax,'off');
    end

    function updateDynamicState()
        if ~isvalid(app.fig), return; end

        a = app.params.a;
        e = app.params.e;
        inc = app.params.inc*pi/180;
        raan = app.params.raan*pi/180;
        argp = app.params.argp*pi/180;
        nu0 = app.params.nu0*pi/180;

        % Convert selected initial true anomaly to E0 and M0.
        E0 = trueToEccentric(nu0,e);
        M0 = mod(E0 - e*sin(E0),2*pi);

        n = sqrt(mu/a^3);                  % rad/s
        M = mod(M0 + n*app.simTime,2*pi);  % propagated mean anomaly
        E = keplerSolver(M,e);
        nu = eccentricToTrue(E,e);

        [rECI,vECI] = orbitalElements2State(mu,a,e,inc,raan,argp,nu);
        vmag = norm(vECI);

        % Update moving graphics.
        if isgraphics(app.hSat)
            app.hSat.XData = rECI(1);
            app.hSat.YData = rECI(2);
            app.hSat.ZData = rECI(3);
        end
        if isgraphics(app.hRadius)
            app.hRadius.XData = [0 rECI(1)];
            app.hRadius.YData = [0 rECI(2)];
            app.hRadius.ZData = [0 rECI(3)];
        end

        % Derived orbital quantities.
        periodHr = 2*pi*sqrt(a^3/mu)/3600;
        periAlt = a*(1-e) - Re;
        apoAlt = a*(1+e) - Re;
        specificEnergy = -mu/(2*a);
        hmag = sqrt(mu*a*(1-e^2));

        % Update text displays.
        app.periodValue.Text = sprintf('%.4f',periodHr);
        app.periValue.Text   = sprintf('%.2f',periAlt);
        app.apoValue.Text    = sprintf('%.2f',apoAlt);
        app.energyValue.Text = sprintf('%.5f',specificEnergy);
        app.hValue.Text      = sprintf('%.3f',hmag);
        app.xValue.Text      = sprintf('%.2f',rECI(1));
        app.yValue.Text      = sprintf('%.2f',rECI(2));
        app.zValue.Text      = sprintf('%.2f',rECI(3));
        app.vValue.Text      = sprintf('%.5f',vmag);
        app.EValue.Text      = sprintf('%.2f',mod(E*180/pi,360));
        app.MValue.Text      = sprintf('%.2f',mod(M*180/pi,360));
        app.nuValue.Text     = sprintf('%.2f',mod(nu*180/pi,360));
        app.timeValue.Text   = sprintf('%.1f',app.simTime);
    end

%% Shutdown
    function onClose(~,~)
        try
            app.isRunning = false;
            if ~isempty(app.animTimer) && isvalid(app.animTimer)
                if strcmp(app.animTimer.Running,'on')
                    stop(app.animTimer);
                end
                delete(app.animTimer);
            end
        catch
            % Best-effort cleanup.
        end

        if isvalid(app.fig)
            delete(app.fig);
        end
    end
end

%% ------------------------------------------------------------------------
function E = keplerSolver(M,e)
%KEPLERSOLVER Solve M = E - e sin(E) for elliptic orbits.
%   M and E are radians. Supports 0 <= e < 1.

M = mod(M,2*pi);
e = max(0,min(e,1-1e-12));

if e < 1e-12
    E = M;
    return;
end

% Robust initial guess.
if e < 0.8
    E = M;
else
    if M < pi
        E = M + 0.85*e;
    else
        E = M - 0.85*e;
    end
end

% Newton-Raphson iteration.
for k = 1:30
    f = E - e*sin(E) - M;
    fp = 1 - e*cos(E);
    dE = -f/fp;
    E = E + dE;
    if abs(dE) < 1e-12
        break;
    end
end

E = mod(E,2*pi);
end

%% ------------------------------------------------------------------------
function [rECI,vECI] = orbitalElements2State(mu,a,e,inc,raan,argp,nu)
%ORBITALELEMENTS2STATE Convert Keplerian elements to ECI state vectors.
%
% Inputs:
%   mu   gravitational parameter, km^3/s^2
%   a    semi-major axis, km
%   e    eccentricity
%   inc  inclination, rad
%   raan right ascension of ascending node, rad
%   argp argument of periapsis, rad
%   nu   true anomaly, rad
%
% Outputs:
%   rECI position vector, km
%   vECI velocity vector, km/s

% Defensive clamps for this elliptic-only demo.
a = max(a,1);
e = max(0,min(e,1-1e-12));

p = a*(1-e^2);
den = 1 + e*cos(nu);
if abs(den) < 1e-12
    den = sign(den + eps)*1e-12;
end
rmag = p/den;

rPF = [rmag*cos(nu); rmag*sin(nu); 0];
vPF = sqrt(mu/p)*[-sin(nu); e + cos(nu); 0];

R = rotateToECI(raan,inc,argp);
rECI = R*rPF;
vECI = R*vPF;
end

%% ------------------------------------------------------------------------
function R = rotateToECI(raan,inc,argp)
%ROTATETOECI Perifocal-to-ECI direction cosine matrix.
%   Uses R3(RAAN)*R1(i)*R3(argPeriapsis).

cO = cos(raan); sO = sin(raan);
ci = cos(inc);  si = sin(inc);
cw = cos(argp); sw = sin(argp);

R = [ cO*cw - sO*sw*ci,  -cO*sw - sO*cw*ci,   sO*si; ...
      sO*cw + cO*sw*ci,  -sO*sw + cO*cw*ci,  -cO*si; ...
      sw*si,                cw*si,               ci    ];
end

%% ------------------------------------------------------------------------
function E = trueToEccentric(nu,e)
%TRUETOECCENTRIC Convert true anomaly to eccentric anomaly for e < 1.

if e < 1e-12
    E = mod(nu,2*pi);
    return;
end

E = 2*atan2(sqrt(1-e)*sin(nu/2), ...
            sqrt(1+e)*cos(nu/2));
E = mod(E,2*pi);
end

%% ------------------------------------------------------------------------
function nu = eccentricToTrue(E,e)
%ECCENTRICTOTRUE Convert eccentric anomaly to true anomaly for e < 1.

if e < 1e-12
    nu = mod(E,2*pi);
    return;
end

nu = 2*atan2(sqrt(1+e)*sin(E/2), ...
             sqrt(1-e)*cos(E/2));
nu = mod(nu,2*pi);
end
