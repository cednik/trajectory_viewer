classdef robot_differential < handle
    
    properties (SetAccess = immutable)
        robot;
        trajectory;
        integration_loop_timer;
        integration_multiplier;
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
            t = struct('simulation', 0, 'virtual', int32(0));
            obj.wheel_left = struct('speed', t, 'position', t);
            obj.wheel_right = obj.wheel_left;
            obj.position = obj.trajectory.Coor(1, :);
            reg_loop_time = 1 / obj.robot.regulationLoopFrequency;
            min_integration_loop_time = 1 / parser.Results.maxLoopFreq;
            if reg_loop_time < min_integration_loop_time
                obj.integration_multiplier = ...
                    obj.robot.regulationLoopFrequency * min_integration_loop_time;
                reg_loop_time = min_integration_loop_time;
            else
                obj.integration_multiplier = 1;
            end
            obj.integration_loop_timer = timer(...
                'BusyMode', 'queue', ...
                'ExecutionMode', 'fixedRate', ...
                'Period', reg_loop_time, ...
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
                case 8
                    obj.wheel_left.speed = set_speed(obj, value, false);
                case 9
                    obj.wheel_right.speed = set_speed(obj, value, true);
                case 12
                    obj.wheel_left.position = set_speed(obj, value, false); %% not correct
                case 13
                    obj.wheel_right.position = set_speed(obj, value, true); %% not correct
                otherwise
                    warning('ROBOT:InvalidRegister', ...
                        'Attempt to set unknown register %d with value %d.', index, value);
            end
        end
        
        function value = get_register(obj, index, type)
            switch(index)
                case 8
                    value = obj.wheel_left.speed.virtual;
                case 9
                    value = -obj.wheel_right.speed.virtual;
                case 12
                    value = obj.wheel_left.position.virtual;
                case 13
                    value = -obj.wheel_right.position.virtual;
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
            stop(obj.integration_loop_timer)
            disp('paused');
        end
        
        function resume(obj)
            start(obj.integration_loop_timer)
            disp('resumed');
        end
    end
    
    %% internal
    methods (Access = protected, Hidden = true)
        % conversion between virtual and simulation units
        function speed = set_speed(obj, virtual, invert)
            if invert
                virtual = -virtual;
            end
            if virtual > obj.robot.maxSpeedValue
                virtual = obj.robot.maxSpeedValue;
            elseif virtual < -obj.robot.maxSpeedValue
                virtual = -obj.robot.maxSpeedValue;
            end
            speed = struct('simulation', ...
                double(virtual) * obj.robot.unitSpeed * obj.integration_multiplier, ...
                'virtual', virtual);
        end
        
        function process(obj)
            obj.wheel_left.position.virtual = obj.c_add_int32(...
                obj.wheel_left.position.virtual, ...
                double(obj.wheel_left.speed.virtual) * obj.integration_multiplier);
            obj.wheel_right.position.virtual = obj.c_add_int32(...
                obj.wheel_right.position.virtual, ...
                double(obj.wheel_right.speed.virtual) * obj.integration_multiplier);
%             obj.wheel_left.position.simulation = ...
%                 obj.wheel_left.position.simulation + obj.wheel_left.speed.simulation ...
%                 * obj.integration_multiplier;
%             obj.wheel_right.position.simulation = ...
%                 obj.wheel_right.position.simulation + obj.wheel_right.speed.simulation ...
%                 * obj.integration_multiplier;
            
            de = [obj.wheel_left.speed.simulation, obj.wheel_right.speed.simulation];
            phi = obj.position(6);
            dphi = (de(2) - de(1)) / obj.robot.trackWidth;
%             if dphi ~= 0
%                 r0 = obj.robot.trackWidth * sum(de) / (2 * (de(2) - de(1)));
%                 dx = r0 * (cos(dphi) * sin(phi) + sin(dphi) * cos(phi) - sin(phi));
%                 dy = r0 * (sin(dphi) * sin(phi) - cos(dphi) * cos(phi) + cos(phi));
%             else
%                 s0 = (de(1) + de(2)) / 2;
%                 dx = s0 * cos(phi);
%                 dy = s0 * sin(phi);
%             end
            % faster approximation
            dphi2 = dphi / 2;
            s0 = (de(1) + de(2)) / 2;
            dx = s0 * cos(phi + dphi2);
            dy = s0 * sin(phi + dphi2);
            obj.position = add_point_rel_fast(obj.trajectory, [dx, dy, 0, 0, 0, dphi]);
        end
    end
    
    methods (Static = true, Access = protected, Hidden = true)
        function res = c_add_int32(a, b)
            res = typecast(int64(a) + int64(b), 'int32');
            res = res(1);
        end
    end
end
