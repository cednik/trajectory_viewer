classdef Trajectory_viewer < handle
    
    properties (Constant)
        settings_file = 'settings.mat'
    end
    
    properties (SetAccess = immutable)%, GetAccess = private)
        gui;
    end
    
    properties (SetAccess = private)
        deleted;
        settings;
        connected;
        trajectory;
        robot;
    end
    
    
    methods
        %% Ctor, Dtor
        function obj = Trajectory_viewer(varargin)
            obj.deleted = false;
            parser = inputParser;
            parser.KeepUnmatched = true;
            parse(parser, varargin{:});
            cat_params = parse_categories(parser.Unmatched, {'gui'});
            obj.trajectory = struct('X', [], 'Y', [], 'Z', [], 't', []);
            obj.robot = struct('X', 0, 'Y', 0, 'Z', 0, 'roll', 0, 'pitch', 0, 'yaw', 0);
            cat_params.gui.DeleteFcn = @obj.delete;
            obj.gui = Gui(cat_params.gui);
            obj.connected = false;
            if exist(obj.settings_file, 'file') == 2
                load(obj.settings_file, 'settings');
                obj.settings = settings;
            else
                obj.settings = struct();
            end
            if ~isfield(obj.settings, 'connection')
                obj.settings.connection = '';
            end
            set(obj.gui.h_connection, 'String', obj.settings.connection);
            set(obj.gui.h_connect_btn, 'Callback', @(src, event)connect(obj));
        end
        
        function delete(obj)
            if obj.deleted
                return
            end
            obj.deleted = true;
            if obj.connected
                obj.connect()
            end
            settings = obj.settings;
            save(obj.settings_file, 'settings');
            if ~obj.gui.deleted
                obj.gui.delete();
            end
        end
        
        %% modifiers
        function connect(obj)
            if obj.connected
                obj.connected = false;
            else
                obj.settings.connection = get(obj.gui.h_connection, 'String');
                obj.connected = true;
            end
            obj.gui.connection_sig(obj.connected);
        end
    end
end

function res = parse_categories(params, categories)
    for i = 1:numel(categories)
        res.(categories{i}) = struct();
    end
    names = fieldnames(params);
    for n = 1:numel(names)
        for c = 1:numel(categories)
            pos = strfind(lower(names{n}), strcat(categories{c}, ':'));
            if ~isempty(pos)
                res.(categories{c}).(...
                    names{n}(pos(1) + length(categories{c}) + 1 : end)) = params.(names{n});
                break;
            end
        end
    end
end