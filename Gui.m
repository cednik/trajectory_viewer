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
        h_deleted_notifee;
    end
    
    properties (SetAccess = private)
        deleted;
        settings;
        robot;
    end
    
    methods
        %% Ctor, Dtor
        function obj = Gui(varargin)
            obj.deleted = false;
            parser = inputParser;
            addOptional(parser, 'DeleteFcn', @()0, @(h)isa(h, 'function_handle'));
            addOptional(parser, 'Position', 'stored', @check_option_position);
            addOptional(parser, 'Robot', []); % FIX-ME add checking
            parse(parser, varargin{:});
            obj.h_deleted_notifee = parser.Results.DeleteFcn;
            if exist(obj.settings_file, 'file') == 2
                load(obj.settings_file, 'settings');
                obj.settings = settings;
            else
                obj.settings = struct();
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
            set(obj.h_fig, 'Visible', 'on');
            xlabel(obj.h_axes, 'X');
            ylabel(obj.h_axes, 'Y');
            zlabel(obj.h_axes, 'Z');
            plot3(obj.h_axes, [0 1], [0 0], [0 0], 'r', 'LineWidth', 2);
            plot3(obj.h_axes, [0 0], [0 1], [0 0], 'g', 'LineWidth', 2);
            plot3(obj.h_axes, [0 0], [0 0], [0 1], 'b', 'LineWidth', 2);
            obj.robot = init_robot(obj.h_axes, parser.Results.Robot);
        end
        
        function delete(obj)
            if obj.deleted
                return
            end
            obj.deleted = true;
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
                dimension = {'X', 'Y', 'Z'};
                r = position.roll;
                p = position.pitch;
                y = position.yaw;
                c = @(x) cos(x);
                s = @(x) sin(x);
                H = zeros(4);
                H(1:3, 1:3) = [ c(y)*c(r), -s(y)*c(p)+c(y)*s(r)*s(p),  s(y)*s(p)+c(y)*s(r)*c(p); ...
                                s(y)*c(r),  c(y)*c(p)+s(y)*s(r)*s(p), -c(y)*s(p)+s(y)*s(r)*c(p); ...
                               -s(y)     ,  c(y)*s(p)               ,  c(y)*c(p)              ];
                for i = 1:3
                    H(i, 4) = position.(dimension{i});
                    dimension{i} = [dimension{i} 'Data'];
                end
                H(4, 4) = position.size;
                for i = 1:numel(obj.robot.handle)
                    h = obj.robot.handle(i);
                    values = obj.robot.symbol{i};
                    for j = 1:size(values, 1)
                        new = H * [values(j, :) 1]';
                        values(j, :) = new(1:3) .* new(4);
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
        function obj = resize(obj)
            control_height = get(obj.h_connect_btn, 'Extent');
            control_height = control_height(4) * 1.5;
            fig_pos = get(obj.h_fig, 'Position');
            set(obj.h_axes_panel, 'Position', [0, 0, fig_pos(3), fig_pos(4) - control_height]);
            set(obj.h_control_panel, 'Position', ...
                [0, fig_pos(4) - control_height, fig_pos(3), control_height]);
            obj.settings.figure_position = get(obj.h_fig, 'OuterPosition');
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
        symbol = cell(2, 1);
        symbol{1} = [0 -1 0; -0.5 -1 0; 0 1 0; 0.5 -1 0; 0 -1 0; 0 1 0];
        symbol{1}(:, 2) = symbol{1}(:, 2) + 1/3;
        symbol{2} = [-0.1 0 0; 0.1 0 0];
    end
    if iscell(symbol)
        robot.is_vector = true;
        robot.handle = zeros(numel(symbol), 1);
        max_val = 0;
        for i = 1:numel(symbol)
            if size(symbol{i}, 2) == 2
                new = zeros(size(symbol{i}) + [0 1]);
                new(:, 1:2) = symbol{i};
                symbol{i} = new;
            end
            m = max(max(abs(symbol{i})));
            if m > max_val
                max_val = m;
            end
        end
        for i = 1:numel(symbol)
            symbol{i} = symbol{i} ./ max_val;
        end
        robot.symbol = symbol;
        for i = 1:numel(symbol)
            robot.handle(i) = plot3(parent, symbol{i}(:, 1), symbol{i}(:, 2), symbol{i}(:, 3), 'k');
        end
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