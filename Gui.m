classdef Gui < handle
    
    properties (Constant)
        settings_file = 'gui_settings.mat'
    end
    
    properties (SetAccess = immutable)
        h_fig;
            h_axes_panel;
            h_control_panel;
                h_connect_btn;
        h_deleted_notifee;
    end
    
    properties (SetAccess = private)
        deleted;
        settings;
    end
    
    methods
        %% Ctor, Dtor
        function obj = Gui(varargin)
            obj.deleted = false;
            parser = inputParser;
            addOptional(parser, 'DeleteFcn', @()0, @(h)isa(h, 'function_handle'))
            addOptional(parser, 'Position', 'stored', @check_option_position)
            parse(parser, varargin{:});
            obj.h_deleted_notifee = parser.Results.DeleteFcn;
            if exist(Gui.settings_file, 'file') == 2
                load(Gui.settings_file, 'settings');
                obj.settings = settings;
            else
                obj.settings = struct();
            end
            figure_options = struct(...
                'name', 'Trajectory viewer', ...
                'Visible', 'off', ...
                'NumberTitle', 'off', ...
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
                'BorderType', 'none', ...
                'BackgroundColor', 'c');
            obj.h_control_panel = uipanel(obj.h_fig, ...
                'Title', '', ...
                'Units', 'pixels', ...
                'BorderType', 'none', ...
                'BackgroundColor', 'm');
            obj.h_connect_btn = uicontrol(obj.h_control_panel, ...
                'Style', 'pushbutton', ...
                'String', 'Connect');
            set(obj.h_fig, 'Visible', 'on');
        end
        
        function delete(obj)
            if obj.deleted
                return
            end
            obj.deleted = true;
            settings = obj.settings;
            save(Gui.settings_file, 'settings');
            obj.h_deleted_notifee();
            if ishandle(obj.h_fig)
                close(obj.h_fig);
            end
        end
    end
    
    
    methods (Access = private)
        %% callbacks
        function obj = resize(obj)
            fig_pos = get(obj.h_fig, 'Position');
            control_width = get(obj.h_connect_btn, 'Extent');
            width = control_width(3) * 1.21;
            set(obj.h_axes_panel, 'Position', [0, 0, fig_pos(3) - width, fig_pos(4)]);
            set(obj.h_control_panel, 'Position', [fig_pos(3) - width, 0, width, fig_pos(4)]);
            set(obj.h_connect_btn, 'Position', [(width - control_width(3)) / 2, ...
                control_width(4)*2, control_width(3), control_width(4)]);
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