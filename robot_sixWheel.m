classdef robot_sixWheel < robot_differential
    
    properties (SetAccess = protected)
        speed;
        alpha;
    end
    
    methods
        %% Ctor, Dtor
        function obj = robot_sixWheel(robot, varargin)
            additional_args = ['start', false, varargin];
            obj = obj@robot_differential(robot, additional_args{:});
            obj.speed = struct('virtual', int32(0), 'real', 0);
            obj.alpha = obj.speed;
            obj.alpha.unit = obj.robot.maxAlpha / double(obj.robot.maxAlphaValue);
            set(obj.integration_loop_timer, 'TimerFcn', @(src, event)process(obj));
            start(obj.integration_loop_timer);
        end
    
        function delete(obj)
            delete@robot_differential(obj);
        end
        
        %% controls
        function set_register(obj, index, value)
            switch(index)
                case 8
                    obj.speed.virtual = ...
                        clamp(value, -obj.robot.maxSpeedValue, obj.robot.maxSpeedValue);
                    obj.speed.real = double(obj.speed.virtual) * obj.unit_speed;
                case 9
                    obj.alpha.virtual = ...
                        clamp(value, -obj.robot.maxAlphaValue, obj.robot.maxAlphaValue);
                    obj.alpha.real = deg2rad(double(obj.alpha.virtual) * obj.alpha.unit);
                otherwise
                    warning('ROBOT:InvalidRegister', ...
                        'Attempt to set unknown register %d with value %d.', index, value);
            end
        end
        
        function value = get_register(obj, index, type)
            switch(index)
                case 8
                    value = obj.speed.virtual;
                case 9
                    value = obj.alpha.virtual;
                otherwise
                    warning('ROBOT:InvalidRegister', ...
                        'Reading unknown register %d.', index);
                    value = int32(0);
            end
            if nargin > 2
                value = cast(value, type);
            end
        end
    end
    
    %% internal
    methods (Access = protected, Hidden = true)
        function process(obj)
            phi = obj.position(6);
            dphi = obj.speed.real * tan(obj.alpha.real) / obj.robot.wheelBase / cos(obj.alpha.real);
            if dphi ~= 0
                r0 = obj.robot.wheelBase / tan(obj.alpha.real);
                dx = r0 * (cos(dphi) * sin(phi) + sin(dphi) * cos(phi) - sin(phi));
                dy = r0 * (sin(dphi) * sin(phi) - cos(dphi) * cos(phi) + cos(phi));
            else
                dx = obj.speed.real * cos(phi);
                dy = obj.speed.real * sin(phi);
            end
            obj.position = add_point_rel_fast(obj.trajectory, [dx, dy, 0, 0, 0, dphi]);
        end
    end
end
