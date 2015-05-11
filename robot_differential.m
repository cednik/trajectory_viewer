classdef robot_differential < handle
    
    properties (SetAccess = immutable)
        robot;
        trajectory;
        integration_loop_timer;
        unit_speed;
        unit_distance;
    end
    
    properties (SetAccess = protected)
        deleted;
        wheel_left;
        wheel_right;
        position;
    end
    
    
    events
        Deleting;
    end
    
    methods
        %% Ctor, Dtor
        function obj = robot_differential(robot, varargin)
            obj.deleted = false;
            parser = inputParser;
            parser.KeepUnmatched = true;
            addOptional(parser, 'start', true, @(v)islogical(v));
            addOptional(parser, 'maxLoopFreq', 1000, @(v)isnumeric(v) && isreal(v) && v <= 1000);
            parse(parser, varargin{:});
            cat_params = parse_categories(parser.Unmatched, {'trajectory'});
            obj.robot = robot;
            obj.trajectory = trajectory_t(cat_params.trajectory);
            obj.wheel_left = struct('virtualSpeed', int32(0), 'speed', 0, 'distance', 0);
            obj.wheel_right = obj.wheel_left;
            obj.position = obj.trajectory.Coor(1, :);
            integration_loop_time = 1 / obj.robot.integrationLoopFrequency;
            min_integration_loop_time = 1 / parser.Results.maxLoopFreq;
            if integration_loop_time < min_integration_loop_time
                integration_loop_time = min_integration_loop_time;
            end
            obj.unit_speed = integration_loop_time * obj.robot.maxSpeed ...
                / double(obj.robot.maxSpeedValue);
            obj.unit_distance = 1 / obj.robot.virtualDistanceUnit;
            obj.integration_loop_timer = timer(...
                'BusyMode', 'queue', ...
                'ExecutionMode', 'fixedRate', ...
                'Period', integration_loop_time, ...
                'TimerFcn', @(~, ~)process(obj), ...
                'Name', sprintf('Integration timer of robot %s', obj.robot.name));
            if parser.Results.start
                start(obj.integration_loop_timer);
            end
        end
    
        function delete(obj)
            if obj.deleted
                return
            end
            obj.deleted = true;
            notify(obj, 'Deleting');
            stop(obj.integration_loop_timer);
            delete(obj.integration_loop_timer);
            delete(obj.trajectory);
        end
        
        %% controls
        function set_register(obj, index, value)
            switch(index)
                case 5
                case 8
                    obj.wheel_left.virtualSpeed = ...
                        clamp(value, -obj.robot.maxSpeedValue, obj.robot.maxSpeedValue);
                    obj.wheel_left.speed = double(obj.wheel_left.virtualSpeed) * obj.unit_speed;
                case 9
                    obj.wheel_right.virtualSpeed = ...
                        clamp(-value, -obj.robot.maxSpeedValue, obj.robot.maxSpeedValue);
                    obj.wheel_right.speed = double(obj.wheel_right.virtualSpeed) * obj.unit_speed;
                case 12
                    obj.wheel_left.distance = double(value) / obj.unit_distance;
                case 13
                    obj.wheel_right.distance = double(-value) / obj.unit_distance;
                otherwise
                    warning('ROBOT:InvalidRegister', ...
                        'Attempt to set unknown register %d with value %d.', index, value);
            end
        end
        
        function value = get_register(obj, index, type)
            switch(index)
                case 8
                    value = obj.wheel_left.virtualSpeed;
                case 9
                    value = -obj.wheel_right.virtualSpeed;
                case 12
                    value = obj.c_cast_int32(obj.wheel_left.distance * obj.unit_distance);
                case 13
                    value = obj.c_cast_int32(-obj.wheel_right.distance * obj.unit_distance);
                otherwise
                    warning('ROBOT:InvalidRegister', ...
                        'Reading unknown register %d.', index);
                    value = int32(0);
            end
            if nargin > 2
                value = cast(value, type);
            end
        end
        
        function pause(obj)
            if strcmp(obj.integration_loop_timer.Running, 'on')
                stop(obj.integration_loop_timer)
            end
        end
        
        function resume(obj)
            if strcmp(obj.integration_loop_timer.Running, 'off')
                start(obj.integration_loop_timer)
            end
        end
    end
    
    %% internal
    methods (Access = protected, Hidden = true)
        
        function process(obj)
            obj.wheel_left.distance = obj.wheel_left.distance + obj.wheel_left.speed;
            obj.wheel_right.distance = obj.wheel_right.distance + obj.wheel_right.speed;
            de = [obj.wheel_left.speed, obj.wheel_right.speed];
            sum_de = de(1) + de(2);
            diff_de = de(2) - de(1);
            phi = obj.position(6);
            dphi = diff_de / obj.robot.trackWidth;
            if dphi ~= 0
                r0 = obj.robot.trackWidth * sum_de / (2 * diff_de);
                dx = r0 * (cos(dphi) * sin(phi) + sin(dphi) * cos(phi) - sin(phi));
                dy = r0 * (sin(dphi) * sin(phi) - cos(dphi) * cos(phi) + cos(phi));
            else
                s0 = sum_de / 2;
                dx = s0 * cos(phi);
                dy = s0 * sin(phi);
            end
            obj.position = add_point_rel_fast(obj.trajectory, [dx, dy, 0, 0, 0, dphi]);
        end
    end
    
    methods (Static = true, Access = protected, Hidden = true)
        function y = c_cast_int32(x)
            y = typecast(int64(x), 'int32');
            y = y(1);
        end
    end
end
