classdef robot_differential4 < robot_differential
    
    methods
        %% Ctor, Dtor
        function obj = robot_differential4(robot, varargin)
            additional_args = ['start', false, varargin];
            obj = obj@robot_differential(robot, additional_args{:});
            wheel = obj.wheel_left;
            obj.wheel_left.front = wheel;
            obj.wheel_left.rear = wheel;
            obj.wheel_right = obj.wheel_left;
            set(obj.integration_loop_timer, 'TimerFcn', @(src, event)process(obj));
            start(obj.integration_loop_timer);
        end
    
        function delete(obj)
            delete@robot_differential(obj);
        end
        
        %% controls
        function set_register(obj, index, value)
            switch(index)
                case 5
                case 8
                    obj.wheel_left.front.virtualSpeed = ...
                        clamp(value, -obj.robot.maxSpeedValue, obj.robot.maxSpeedValue);
                    obj.wheel_left.speed = (double(obj.wheel_left.front.virtualSpeed) ...
                        + double(obj.wheel_left.rear.virtualSpeed)) ...
                        * obj.unit_speed / 2;
                case 9
                    obj.wheel_left.rear.virtualSpeed = ...
                        clamp(value, -obj.robot.maxSpeedValue, obj.robot.maxSpeedValue);
                    obj.wheel_left.speed = (double(obj.wheel_left.front.virtualSpeed) ...
                        + double(obj.wheel_left.rear.virtualSpeed)) ...
                        * obj.unit_speed / 2;
                case 10
                    obj.wheel_right.front.virtualSpeed = ...
                        clamp(-value, -obj.robot.maxSpeedValue, obj.robot.maxSpeedValue);
                    obj.wheel_right.speed = (double(obj.wheel_right.front.virtualSpeed) ...
                        + double(obj.wheel_right.rear.virtualSpeed)) ...
                        * obj.unit_speed / 2;
                case 11
                    obj.wheel_right.rear.virtualSpeed = ...
                        clamp(-value, -obj.robot.maxSpeedValue, obj.robot.maxSpeedValue);
                    obj.wheel_right.speed = (double(obj.wheel_right.front.virtualSpeed) ...
                        + double(obj.wheel_right.rear.virtualSpeed)) ...
                        * obj.unit_speed / 2;
                case 12
                    obj.wheel_left.front.distance = double(value) / obj.unit_distance;
                case 13
                    obj.wheel_left.rear.distance = double(value) / obj.unit_distance;
                case 14
                    obj.wheel_right.front.distance = double(-value) / obj.unit_distance;
                case 15
                    obj.wheel_right.rear.distance = double(-value) / obj.unit_distance;
                otherwise
                    warning('ROBOT:InvalidRegister', ...
                        'Attempt to set unknown register %d with value %d.', index, value);
            end
        end
        
        function value = get_register(obj, index, type)
            switch(index)
                case 8
                    value = obj.wheel_left.front.virtualSpeed;
                case 9
                    value = obj.wheel_left.rear.virtualSpeed;
                case 10
                    value = -obj.wheel_right.front.virtualSpeed;
                case 11
                    value = -obj.wheel_right.rear.virtualSpeed;
                case 12
                    value = obj.c_cast_int32(obj.wheel_left.front.distance * obj.unit_distance);
                case 13
                    value = obj.c_cast_int32(obj.wheel_left.rear.distance * obj.unit_distance);
                case 14
                    value = obj.c_cast_int32(-obj.wheel_right.front.distance * obj.unit_distance);
                case 15
                    value = obj.c_cast_int32(-obj.wheel_right.rear.distance * obj.unit_distance);
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
            obj.wheel_left.front.distance = obj.wheel_left.front.distance + obj.wheel_left.speed;
            obj.wheel_left.rear.distance = obj.wheel_left.rear.distance + obj.wheel_left.speed;
            obj.wheel_right.front.distance = obj.wheel_right.front.distance + obj.wheel_left.speed;
            obj.wheel_right.rear.distance = obj.wheel_right.rear.distance + obj.wheel_left.speed;
            process@robot_differential(obj);
        end
    end
end
