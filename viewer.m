classdef viewer < handle
    
    properties (Constant)
        settings_file = 'viewer_settings.mat'
    end
    
    properties (SetAccess = immutable)
        h_fig;
            h_axes_panel;
                h_axes;
            h_status_panel;
                h_fps;
                h_message;
                h_robot_info;
        h_refresh_timer;
        robots;
    end
    
    properties (SetAccess = private)
        deleted;
        settings;
    end
    
    events
        Deleting;
    end
    
    methods
        %% Ctor, Dtor
        function obj = viewer(robots, varargin)
            obj.deleted = false;
            parser = inputParser;
            addOptional(parser, 'Position', 'stored', @check_option_position);
            addOptional(parser, 'Fps', 0, @(v)isnumeric(v) && v(1) > 0 && v(1) <= 1000);
            parse(parser, varargin{:});
            if exist(obj.settings_file, 'file') == 2
                load(obj.settings_file, 'settings');
                obj.settings = settings;
            else
                obj.settings = struct();
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
            obj.h_status_panel = uipanel(obj.h_fig, ...
                'Title', '', ...
                'Units', 'pixels', ...
                'BorderType', 'none');
            obj.h_fps = uicontrol(obj.h_status_panel, ...
                'Style', 'text', ...
                'FontName', 'FixedWidth', ...
                'HorizontalAlignment', 'left', ...
                'String', fps2str(0, 0));
            pos = get(obj.h_fps, 'Extent');
            set(obj.h_fps, 'Position', [20, pos(4) / 3, pos(3) * 1.5, pos(4)]);
            obj.h_message = uicontrol(obj.h_status_panel, ...
                'Style', 'text', ...
                'FontName', 'FixedWidth', ...
                'HorizontalAlignment', 'left', ...
                'String', 'Ready');
            obj.h_robot_info = uicontrol(obj.h_status_panel, ...
                'Style', 'text', ...
                'FontName', 'FixedWidth', ...
                'HorizontalAlignment', 'left', ...
                'String', '');
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
            if ~iscell(robots)
                robots = {robots};
            end
            obj.robots = repmat(...
                struct('trajectory', struct(), 'trajectory_handle', 0, 'symbol', struct()), ...
                length(robots), 1);
            for i = 1:length(robots)
                obj.robots(i).trajectory = robots{i}.trajectory;
                obj.robots(i).trajectory_handle = ...
                    plot3(obj.h_axes, nan, nan, nan, obj.robots(i).trajectory.style);
                obj.robots(i).symbol = init_robot(obj.h_axes, robots{i}.robot.symbol);
            end
            set(obj.h_fig, 'Visible', 'on');
            obj.h_refresh_timer = timer(...
                'BusyMode', 'drop', ...
                'ExecutionMode', 'fixedRate', ...
                'Period', 1 / obj.settings.Fps, ...
                'TimerFcn', @(src, event)refresh(obj), ...
                'Name', 'Viewer refresh timer');
            start(obj.h_refresh_timer);
        end
        
        function delete(obj)
            if obj.deleted
                return
            end
            obj.deleted = true;
            stop(obj.h_refresh_timer);
            drawnow;
            notify(obj, 'Deleting');
            settings = obj.settings;
            save(obj.settings_file, 'settings');
            if ishandle(obj.h_fig)
                close(obj.h_fig);
            end
        end
        
        %% modifiers
        function set_message(obj, message)
            set(obj.h_message, 'String', message);
        end
        
        function draw_robot(obj, robot)
            position = robot.trajectory.coor(robot.trajectory.points, :);
            robot = robot.symbol;
            if robot.is_vector
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
                max_axis = max(diff(reshape(lim, 2, length(lim) / 2))) / 2;
                if (robot.size / max_axis) < robot.min_size
                    scale = max_axis * robot.min_size;
                else
                    scale = robot.size;
                end
                if robot.size == 0
                    show_scale = 1;
                else
                    show_scale = scale / robot.size;
                end
                set(obj.h_robot_info, 'String', robot_info(position, show_scale));
                for i = 1:numel(robot.handle)
                    h = robot.handle(i);
                    values = robot.symbol{i} .* scale;
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
            status_height = get(obj.h_fps, 'Extent');
            fps_width = status_height(3);
            status_texts_height = status_height(4);
            status_height = status_height(4) * 2.5;
            fig_pos = get(obj.h_fig, 'Position');
            set(obj.h_axes_panel, 'Position', ...
                [0, status_height, fig_pos(3), fig_pos(4) - status_height]);
            set(obj.h_status_panel, 'Position', ...
                [0, 0, fig_pos(3), status_height]);
            set(obj.h_message, 'Position', [fps_width + fig_pos(3) / 20, status_texts_height/3, ...
                fig_pos(3) - fps_width - fig_pos(3) / 20, status_texts_height]);
            set(obj.h_robot_info, 'Position', [20, status_texts_height*5/3, ...
                fig_pos(3), status_texts_height]);
            obj.settings.figure_position = get(obj.h_fig, 'OuterPosition');
            
        end
        
        function refresh(obj)
            set(obj.h_fps, 'String', fps2str(...
                get(obj.h_refresh_timer, 'InstantPeriod'), ...
                get(obj.h_refresh_timer, 'AveragePeriod')));
            for i = 1:length(obj.robots)
                r = obj.robots(i);
                if ~r.trajectory.updated
                    continue;
                end
                coor = r.trajectory.coor;
                set(r.trajectory_handle, ...
                    'XData', coor(:, 1), ...
                    'YData', coor(:, 2), ...
                    'ZData', coor(:, 3));
                draw_robot(obj, r);
            end
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
    default_min_size = 0.05;
    default_size = 1;
    if isstruct(symbol)
        if isfield(symbol, 'size')
            robot.size = symbol.size;
        else
            robot.size = default_size;
        end
        if isfield(symbol, 'minSize')
            robot.min_size = symbol.minSize;
        else
            robot.min_size = default_min_size;
        end
        if isfield(symbol, 'symbol')
            symbol = symbol.symbol;
        else
            symbol = [];
        end
    else
        robot.min_size = default_min_size;
    end
    if isempty(symbol)
        if ~isfield(robot, 'size')
            robot.size = default_size;
        end
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
        if ~isfield(robot, 'size')
            robot.size = max_val;
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

function s = robot_info(coor, scale)
    rpy = round(rad2deg(coor(4:6)));
    s = sprintf(...
        'Robot: coordinates = [X: %s; Y: %s; Z: %s; R: %4d; P: %4d; Y: %4d] scale = %7.3f', ...
        coor2str(coor(1)), coor2str(coor(2)), coor2str(coor(3)), rpy(1), rpy(2), rpy(3), scale);
end

function s = coor2str(coor)
    s = num2str(coor, 4);
end