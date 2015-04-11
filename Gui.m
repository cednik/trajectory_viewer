classdef Gui < handle
    
    properties (Constant)
        settings_file = 'gui_settings.mat'
    end
    
    properties (SetAccess = immutable)
        h_fig;
            h_axes_panel;
                h_axes;
            h_control_panel;
                h_connect_btn;
                h_connection;
            h_status_panel;
                h_fps;
        h_deleted_notifee;
        h_refresh_timer;
        h_trajectory_getter;
    end
    
    properties (SetAccess = private)
        deleted;
        settings;
        robot;
        h_trajectory;
    end
    
    methods
        %% Ctor, Dtor
        function obj = Gui(trajectory_getter, varargin)
            obj.deleted = false;
            parser = inputParser;
            addOptional(parser, 'DeleteFcn', @()0, @(h)isa(h, 'function_handle'));
            addOptional(parser, 'Position', 'stored', @check_option_position);
            addOptional(parser, 'Robot', []); % FIX-ME add checking
            addOptional(parser, 'RobotSize', 0, @(v)isnumeric(v) && v(1) > 0 && v(1) <= 1);
            addOptional(parser, 'Fps', 0, @(v)isnumeric(v) && v(1) > 0 && v(1) <= 1000);
            parse(parser, varargin{:});
            obj.h_deleted_notifee = parser.Results.DeleteFcn;
            obj.h_trajectory_getter = trajectory_getter;
            if exist(obj.settings_file, 'file') == 2
                load(obj.settings_file, 'settings');
                obj.settings = settings;
            else
                obj.settings = struct();
            end
            if parser.Results.RobotSize ~= 0
                obj.settings.RobotSize = parser.Results.RobotSize;
            elseif ~isfield(obj.settings, 'RobotSize')
                obj.settings.RobotSize = 0.1;
            end
            if parser.Results.Fps ~= 0
                obj.settings.Fps = parser.Results.Fps;
            elseif ~isfield(obj.settings, 'Fps')
                obj.settings.Fps = 10;
            end
            figure_options = struct(...
                'name', 'Trajectory viewer', ...
                'Visible', 'off', ...
                'NumberTitle', 'off', ...
                'ToolBar', 'figure', ...
                'MenuBar', 'none', ...
                conditional(version_diff('R2014b') > 0, 'SizeChangedFcn', 'ResizeFcn'), ...
                    @(src, event)resize(obj), ...
                'DeleteFcn', @(src, event)delete(obj));
            if ~isfield(obj.settings, 'figure_position')
                obj.settings.figure_position = [];
            end
            figure_options = parse_option_position(figure_options, parser.Results.Position, ...
                obj.settings.figure_position);
            obj.h_fig = figure(figure_options);
            obj.h_control_panel = uipanel(obj.h_fig, ...
                'Title', '', ...
                'Units', 'pixels', ...
                'BorderType', 'none');
            obj.h_connect_btn = uicontrol(obj.h_control_panel, ...
                'Style', 'pushbutton', ...
                'String', 'Connect');
            pos = get(obj.h_connect_btn, 'Extent');
            set(obj.h_connect_btn, 'Position', [pos(3) / 4, pos(4) / 3, pos(3) * 1.5, pos(4)]);
            obj.h_connection = uicontrol(obj.h_control_panel, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', 'white', ...
                'Position', [pos(3) * 2, pos(4) / 3, pos(3) * 4, pos(4)]);
            obj.h_status_panel = uipanel(obj.h_fig, ...
                'Title', '', ...
                'Units', 'pixels', ...
                'BorderType', 'none');
            obj.h_fps = uicontrol(obj.h_status_panel, ...
                'Style', 'text', ...
                'HorizontalAlignment', 'left', ...
                'String', fps2str(0, 0));
            pos = get(obj.h_fps, 'Extent');
            set(obj.h_fps, 'Position', [20, pos(4) / 3, pos(3) * 1.5, pos(4)]);
            obj.h_axes_panel = uipanel(obj.h_fig, ...
                'Title', '', ...
                'Units', 'pixels', ...
                'BorderType', 'none');
            obj.h_axes = axes('Parent', obj.h_axes_panel, ...
                'XGrid', 'on', ...
                'YGrid', 'on', ...
                'ZGrid', 'on', ...
                'NextPlot', 'add', ...
                'CameraViewAngleMode', 'auto');
            xlabel(obj.h_axes, 'X');
            ylabel(obj.h_axes, 'Y');
            zlabel(obj.h_axes, 'Z');
            axis(obj.h_axes, 'equal');
            plot3(obj.h_axes, [0 1], [0 0], [0 0], 'r', 'LineWidth', 2);
            plot3(obj.h_axes, [0 0], [0 1], [0 0], 'g', 'LineWidth', 2);
            plot3(obj.h_axes, [0 0], [0 0], [0 1], 'b', 'LineWidth', 2);
            obj.robot = init_robot(obj.h_axes, parser.Results.Robot);
            obj.h_trajectory = plot3(obj.h_axes, nan, nan, nan, 'm');
            set(obj.h_fig, 'Visible', 'on');
            obj.h_refresh_timer = timer(...
                'BusyMode', 'drop', ...
                'ExecutionMode', 'fixedRate', ...
                'Period', 1 / obj.settings.Fps, ...
                'TimerFcn', @(src, event)refresh(obj));
            start(obj.h_refresh_timer);
        end
        
        function delete(obj)
            if obj.deleted
                return
            end
            obj.deleted = true;
            stop(obj.h_refresh_timer);
            %clear(obj.h_refresh_timer);
            settings = obj.settings;
            save(obj.settings_file, 'settings');
            obj.h_deleted_notifee();
            if ishandle(obj.h_fig)
                close(obj.h_fig);
            end
        end
        
        %% modifiers
        function connection_sig(obj, connected)
            if connected
                set(obj.h_connect_btn, 'String', 'Disconnect');
                set(obj.h_connection, 'Enable', 'off');
            else
                set(obj.h_connect_btn, 'String', 'Connect');
                set(obj.h_connection, 'Enable', 'on');
            end
        end
        
        function set_robot_position(obj, position)
            if obj.robot.is_vector
                dimension = {'XData', 'YData', 'ZData'};
                r = position(4);
                p = position(5);
                y = position(6);
                H = zeros(4);
                H(1:3, 1:3) = ...
    [cos(y)*cos(p), -sin(y)*cos(r)+cos(y)*sin(p)*sin(r),  sin(y)*sin(r)+cos(y)*sin(p)*cos(r); ...
     sin(y)*cos(p),  cos(y)*cos(r)+sin(y)*sin(p)*sin(r), -cos(y)*sin(r)+sin(y)*sin(p)*cos(r); ...
           -sin(p),                       cos(p)*sin(r),                       cos(p)*cos(r)];
                H(:, 4) = [position(1:3)'; 1];
                lim = axis(obj.h_axes);
                scale = max(diff(reshape(lim, 2, length(lim) / 2))) * obj.settings.RobotSize;
                for i = 1:numel(obj.robot.handle)
                    h = obj.robot.handle(i);
                    values = obj.robot.symbol{i} .* scale;
                    for j = 1:size(values, 1)
                        new = H * [values(j, :) 1]';
                        values(j, :) = new(1:3);
                    end
                    for k = 1:3
                        set(h, dimension{k}, values(:, k));
                    end
                end
            else
            end
        end
    end
    
    
    methods (Access = private)
        %% callbacks
        function resize(obj)
            control_height = get(obj.h_connect_btn, 'Extent');
            control_height = control_height(4) * 1.5;
            status_height = get(obj.h_fps, 'Extent');
            status_height = status_height(4) * 1.5;
            fig_pos = get(obj.h_fig, 'Position');
            set(obj.h_axes_panel, 'Position', ...
                [0, status_height, fig_pos(3), fig_pos(4) - control_height - status_height]);
            set(obj.h_control_panel, 'Position', ...
                [0, fig_pos(4) - control_height, fig_pos(3), control_height]);
            set(obj.h_status_panel, 'Position', ...
                [0, 0, fig_pos(3), status_height]);
            obj.settings.figure_position = get(obj.h_fig, 'OuterPosition');
            
        end
        
        function refresh(obj)
            set(obj.h_fps, 'String', fps2str(...
                get(obj.h_refresh_timer, 'InstantPeriod'), ...
                get(obj.h_refresh_timer, 'AveragePeriod')));
            trajectory = obj.h_trajectory_getter();
            if islogical(trajectory)
                return;
            end
            set(obj.h_trajectory, ...
                'XData', trajectory(:, 1), ...
                'YData', trajectory(:, 2), ...
                'ZData', trajectory(:, 3));
            set_robot_position(obj, trajectory(end, :));
            drawnow;
        end
    end
end


function ok = check_option_position(value)
    ok = (ischar(value) && any(strcmpi(value, {'default', 'stored'}))) ...
        || (isvector(value) && length(value) == 4);
end

function res = parse_option_position(others, arg, stored)
    res = others;
    if ischar(arg)
        %if strcmpi(arg, 'default')
        if strcmpi(arg, 'stored')
            if length(stored) == 4 % FIX-ME: show warning otherwise
                res.OuterPosition = stored;
            end
        end % FIX-ME: error('unknown option')
    elseif isvector(arg) && length(arg) == 4
        res.OuterPosition = arg;
    end % FIX-ME: error('unknown option type')
end


function robot = init_robot(parent, symbol)
    if isempty(symbol)
        symbol = { ...
        {[-1, -0.5,  0  ; -1, 0.5, 0  ], struct('Color', 'k', 'LineWidth', 2)}, ...
        {[-1, -0.5,  0  ;  1, 0  , 0  ], struct('Color', 'g', 'LineWidth', 2)}, ...
        {[-1,  0.5,  0  ;  1, 0  , 0  ], struct('Color', 'r', 'LineWidth', 2)}, ...
        {[-1,  0  ,  0  ;  1, 0  , 0  ], 'k'}, ...
         [ 0, -0.2,  0  ;  0, 0.2, 0  ], ...
         [ 0,  0  , -0.2;  0, 0  , 0.2]};
        for i = 1:4
            symbol{i}{1}(:, 1) = symbol{i}{1}(:, 1) + 1/3;
        end
    end
    if iscell(symbol)
        robot.is_vector = true;
        robot.handle = zeros(numel(symbol), 1);
        max_val = 0;
        for i = 1:numel(symbol)
            line_style = 'k';
            if iscell(symbol{i})
                line_style = symbol{i}{2};
                symbol{i} = symbol{i}{1};
            end
             if size(symbol{i}, 2) == 2
                new = zeros(size(symbol{i}) + [0 1]);
                new(:, 1:2) = symbol{i};
                symbol{i} = new;
            end
            m = max(max(abs(symbol{i})));
            if m > max_val
                max_val = m;
            end
            robot.handle(i) = ...
                plot3(parent, symbol{i}(:, 1), symbol{i}(:, 2), symbol{i}(:, 3), line_style);
        end
        for i = 1:numel(symbol)
            symbol{i} = symbol{i} ./ max_val;
        end
        robot.symbol = symbol;
        return;
    end
    if ischar(symbol)
        symbol = imread(symbol);
    end
    if ismatrix(symbol)
        robot.is_vector = false;
        robot.handle = image(symbol);
        return;
    end
    error('Trajectory_viewer:Gui:TypeError', ...
        'Robot symbol must be cell array, matrix or string.');
end

function s = fps2str(current, average)
    s = sprintf('fps: %6.2f (avg %5.2f)', 1 / current, 1 / average);
end