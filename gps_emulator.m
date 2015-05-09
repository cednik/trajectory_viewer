classdef gps_emulator < handle
    
    properties (Constant = true)
        sentence_format = {...
            '$%sGGA,%s,%02d%09.6f,%c,%03d%09.6f,%c,4,08,1.2,%.3f,M,%.3f,M,1,0000*00\r\n', ...
            ...% sentence 2: fixed values, nothing to emulate
            '$%sGST,%s,0.000,0.004,0.003,4.4,0.004,0.003,0.007*00\r\n', ...
            '$PTNL,AVR,%s,%+.4f,Yaw,%+.4f,Tilt,,,1.077,3,2,6,08*00\r\n'};
        max_msg_length = 256;
    end
    
    properties (SetAccess = immutable)
        robot;
        connection;
        get_utc_time;
        sending_timer;
    end
    
    properties (SetAccess = protected)
        deleted;
        home_coor;
        msg;
        ptr;
    end
    
    methods
        %% Ctor, Dtor
        function obj = gps_emulator(robot, varargin)
            obj.deleted = false;
            obj.robot = robot;
            addlistener(robot, 'Deleting', @(~, ~)delete(obj));
            parser = inputParser;
            parser.KeepUnmatched = true;
            addOptional(parser, 'fps', 20, @(v)isnumeric(v) && isreal(v) && v > 0 && v <= 1000);
            addOptional(parser, 'homeCoordinates', [0 0 0], ...
                @(v)isnumeric(v) && isreal(v) && length(v) > 1 && length(v) < 4);
            addOptional(parser, 'UTCoffset', [], @(v)ischar(v) || (isnumeric(v) && isreal(v)));
            addOptional(parser, 'start', true, @(v)islogical(v));
            parse(parser, varargin{:});
            obj.home_coor = parser.Results.homeCoordinates;
            if length(obj.home_coor) < 3
                obj.home_coor = [obj.home_coor 0];
            end
            cat_params = parse_categories(parser.Unmatched, {'udp'});
            obj.connection = udp_params_parser(cat_params.udp);
            set(obj.connection, 'DatagramReceivedFcn', ...
                @(src, event)recv(src, event, 'GPS emulator received data on '));
            obj.msg = char(zeros(1, obj.max_msg_length));
            if version_diff('R2014b') >= 0
                zone = parser.Results.UTCoffset;
                if isempty(zone)
                    zone = 'utc';
                elseif isnumeric(zone)
                    hours = fix(zone);
                    minutes = round(59 * abs(zone - hours));
                    zone = sprintf('%+d:%02d', hours, minutes);
                end
                obj.get_utc_time = @()datetime('now', 'timezone', zone, 'format', 'HHmmss.SSS');
            else
                offset = parser.Results.UTCoffset;
                if isempty(offset)
                    if is_toolbox_available('mapping toolbox')
                        [offset, ~, ~] = timezone(obj.home_coor(2));
                    else
                        offset = 0;
                    end
                elseif ischar(offset)
                    sep = strfind(offset, ':');
                    if isempty(sep)
                        error('GPS:InvalidUTCOffset', 'Invalid format of UTC offset input.');
                    end
                    hours = str2double(offset(1:sep(1)-1));
                    minutes = str2double(offset(sep(1)+1:end));
                    minutes  = minutes / 60;
                    offset = hours + conditional(hours < 0, -minutes, minutes);
                end
                offset = offset / 24;
                obj.get_utc_time = @()datestr(datenum(clock()) + offset, 'HHMMSS.FFF');
            end
            geoid_height(obj.home_coor(1), obj.home_coor(2), 'egm96-5', 'geoids');
            obj.sending_timer = timer(...
                'BusyMode', 'queue', ...
                'ExecutionMode', 'fixedRate', ...
                'Period', 1 / parser.Results.fps, ...
                'TimerFcn', @(~, ~)process(obj), ...
                'Name', sprintf('Sending timer of %s''s GPS emulator', obj.robot.robot.name));
            fopen(obj.connection);
            if parser.Results.start
                start(obj.sending_timer);
            end
        end
        
        function delete(obj)
            if obj.deleted
                return
            end
            obj.deleted = true;
            stop(obj.sending_timer);
            delete(obj.sending_timer);
            fclose(obj.connection);
            delete(obj.connection);
        end
        
        function pause(obj)
            if strcmp(obj.sending_timer.Running, 'on')
                stop(obj.sending_timer)
            end
        end
        
        function resume(obj)
            if strcmp(obj.sending_timer.Running, 'off')
                start(obj.sending_timer)
            end
        end
    end
    
    methods (Access = private, Hidden = true)
        function process(obj)
            t = obj.get_utc_time();
            coor = obj.robot.position;
            [lat, lon] = geodreckon(obj.home_coor(1), obj.home_coor(2), ...
                pdist([0 0; coor(1:2)]), rad2deg(mod(2.5*pi-atan2(coor(2), coor(1)), 2*pi)));
            height_correction = geoid_height(lat, lon, 'egm96-5', 'geoids');
            if lat < 0
                latdir = 'S';
                lat = -lat;
            else
                latdir = 'N';
            end
            if lon < 0
                londir = 'W';
                lon = -lon;
            else
                londir = 'E';
            end
            latlon = zeros(2);
            latlon(:, 1) = fix([lat; lon]);
            latlon(:, 2) = ([lat; lon] - latlon(:, 1)) * 60;
            obj.ptr = 1;
            add_sentence(obj, 1, 'GP', t, ...
                latlon(1, 1), latlon(1, 2), latdir, ...
                latlon(2, 1), latlon(2, 2), londir, ...
                coor(3), height_correction);
            add_sentence(obj, 2, 'GN', t);
            add_sentence(obj, 3, t, rad2deg(mod(2.5*pi-coor(6), 2*pi)), ...
                rad2deg(mod(2*pi+coor(5), 2*pi)));
            fwrite(obj.connection, obj.msg(1:obj.ptr-1));
        end
        
        function add_sentence(obj, sentence_num, varargin)
            sentence = add_checksum(sprintf(obj.sentence_format{sentence_num}, varargin{:}));
            stop = obj.ptr + length(sentence);
            obj.msg(obj.ptr:stop-1) = sentence;
            obj.ptr = stop;
        end
    end
end

function sentence = add_checksum(sentence)
    cs = uint8(0);
    stop = length(sentence) - 5;
    for i = 2:stop
        cs = bitxor(cs, uint8(sentence(i)));
    end
    sentence(stop+2:stop+3) = sprintf('%02X', cs);
end
