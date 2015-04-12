classdef Trajectory_viewer < handle
    
    properties (Constant)
        settings_file = 'settings.mat';
        init_alloc_size = 72000; % 1 Hour @ 20 Hz input
        
    end
    
    properties (SetAccess = immutable)%, GetAccess = private)
        gui;
        com_parser;
    end
    
    properties (SetAccess = private)
        deleted;
        settings;
        connected;
        connection;
        trajectory;
    end
    
    
    methods
        %% Ctor, Dtor
        function obj = Trajectory_viewer(com_parser, varargin)
            obj.deleted = false;
            parser = inputParser;
            parser.KeepUnmatched = true;
            parse(parser, varargin{:});
            cat_params = parse_categories(parser.Unmatched, {'gui'});
            obj.trajectory.coor = NaN(obj.init_alloc_size, 6);
            obj.trajectory.time = cell(obj.init_alloc_size, 1);
            obj.trajectory.length = 1;
            obj.trajectory.updated = true;
            obj.trajectory.coor(1, :) = zeros(1, size(obj.trajectory.coor, 2));
            obj.trajectory.time{1} = clock();
            cat_params.gui.DeleteFcn = @obj.delete;
            obj.gui = Gui(@()get_trajectory(obj), cat_params.gui);
            obj.com_parser = com_parser;
            if isobject(obj.com_parser)
                set_plot_fcn(obj.com_parser, @obj.add_point);
            end
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
                connect(obj)
            end
            if isobject(obj.connection)
                delete(obj.connection);
            end
            settings = obj.settings;
            save(obj.settings_file, 'settings');
            %clear(obj.trajectory);
            if ~obj.gui.deleted
                delete(obj.gui);
            end
            if isobject(obj.com_parser)
                delete(obj.com_parser);
            end
        end
        
        %% modifiers
        function connect(obj)
            if obj.connected
                fclose(obj.connection);
                set_message(obj.gui, 'Disconnected');
                obj.connected = false;
            else
                obj.settings.connection = get(obj.gui.h_connection, 'String');
                if ~isempty(obj.connection)
                    delete(obj.connection);
                end
                try
                    % FIX-ME should write my own parser, because security
                    obj.connection = eval(obj.settings.connection);
                    if isobject(obj.com_parser)
                        datacallback = ...
                            @(src, event)obj.com_parser.process(obj.connection);
                    else
                        datacallback = @(src, event)obj.com_parser(obj.connection, @obj.add_point);
                    end
                    if isa(obj.connection, 'udp')
                        set(obj.connection, 'DatagramReceivedFcn', datacallback);
                    else
                        set(obj.connection, ...
                            'BytesAvailableFcnCount', 1, ...
                            'BytesAvailableFcnMode', 'byte', ...
                            'BytesAvailableFcn', datacallback);
                    end
                    fopen(obj.connection);
                    set_message(obj.gui, 'Connected');
                    obj.connected = true;
                catch ME
                    switch ME.identifier
                        case 'MATLAB:UndefinedFunction'
                            beep;
                            errordlg(['Incorrect expression "', obj.settings.connection, ...
                                '" in connection input row!'], 'Incorrect expresion', 'modal');
                        case 'instrument:fopen:opfailed'
                            set_message(obj.gui, 'Can not open connection!');
                            beep;
                        otherwise
                            set_message(obj.gui, ...
                                ['Exception "', ME.identifier, '" occured during connection']);
                            beep;
                    end
                end
            end
            obj.gui.connection_sig(obj.connected);
        end
        
        function add_point(obj, coor, absolute, time)
            if nargin < 4
                time = clock();
                if nargin < 3
                    absolute = false;
                end
            end
            if size(obj.trajectory.coor, 1) == obj.trajectory.length %% realloc if full
                obj.trajectory.coor = [obj.trajectory.coor; NaN(size(obj.trajectory.coor))];
                obj.trajectory.time = {obj.trajectory.time; cell(size(obj.trajectory.time))};
            end
            obj.trajectory.length = obj.trajectory.length + 1;
            if length(coor) == 2
                coor = [coor, 0];
            end
            abs_rot = absolute;
            if length(coor) == 3
                abs_rot = true;
                if absolute
                    [r p y] = calc_orientation(obj);
                else
                    [r p y] = calc_orientation(obj, coor);
                end
                coor = [coor, r, p, y];
            elseif length(coor) ~= size(obj.trajectory.coor, 2)
                coor = [coor, zeros(1, size(obj.trajectory.coor, 2) - length(coor))];
            end
            if absolute
                obj.trajectory.coor(obj.trajectory.length, :) = coor;
            else
                if ~any(coor)
                    return;
                end
                if abs_rot
                    obj.trajectory.coor(obj.trajectory.length, 1:3) = ...
                        coor(1:3) + obj.trajectory.coor(obj.trajectory.length - 1, 1:3);
                    obj.trajectory.coor(obj.trajectory.length, 4:6) = coor(4:6);
                else
                    obj.trajectory.coor(obj.trajectory.length, :) = ...
                        coor + obj.trajectory.coor(obj.trajectory.length - 1, :);
                end
            end
            obj.trajectory.time{obj.trajectory.length} = time;
            obj.trajectory.updated = true;
        end
    
        function t = get_trajectory(obj, force)
            if obj.trajectory.updated || (nargin > 1 && force)
                t = obj.trajectory.coor(1:obj.trajectory.length, :);
                obj.trajectory.updated = false;
            else
                t = false;
            end
        end
        
        function [r p y] = calc_orientation(obj, dif)
            l = obj.trajectory.length;
            if nargin == 1 || isempty(dif)
                dif = diff(obj.trajectory.coor(l-1:l, 1:3));
            end
            r = 0;
            p = atan2(sqrt(sum(dif(1:2).^2)), dif(3)) - pi/2;
            if dif(1) == 0 && dif(2) == 0
                y = obj.trajectory.coor(l-1, 6);
            else
                y = atan2(dif(2), dif(1));
            end
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