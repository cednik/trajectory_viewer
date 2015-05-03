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
                case 8
                    obj.wheel_left.front.speed = set_speed(obj, value, false);
                    obj.wheel_left.speed = speed_average(obj.wheel_left);
                case 9
                    obj.wheel_left.rear.speed = set_speed(obj, value, false);
                    obj.wheel_left.speed = speed_average(obj.wheel_left);
                case 10
                    obj.wheel_right.front.speed = set_speed(obj, value, true);
                    obj.wheel_right.speed = speed_average(obj.wheel_right);
                case 11
                    obj.wheel_right.rear.speed = set_speed(obj, value, true);
                    obj.wheel_right.speed = speed_average(obj.wheel_right);
                case 12
                    obj.wheel_left.front.position.virtual = value; %% not correct
                case 13
                    obj.wheel_left.rear.position.virtual = value; %% not correct
                case 14
                    obj.wheel_right.front.position.virtual = -value; %% not correct
                case 15
                    obj.wheel_right.rear.position.virtual = -value; %% not correct
                otherwise
                    warning('ROBOT:InvalidRegister', ...
                        'Attempt to set unknown register %d with value %d.', index, value);
            end
        end
        
        function value = get_register(obj, index, type)
            switch(index)
                case 8
                    value = obj.wheel_left.front.speed.virtual;
                case 9
                    value = obj.wheel_left.rear.speed.virtual;
                case 10
                    value = -obj.wheel_right.front.speed.virtual;
                case 11
                    value = -obj.wheel_right.rear.speed.virtual;
                case 12
                    value = obj.wheel_left.front.position.virtual;
                case 13
                    value = obj.wheel_left.rear.position.virtual;
                case 14
                    value = -obj.wheel_right.front.position.virtual;
                case 15
                    value = -obj.wheel_right.rear.position.virtual;
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
            obj.wheel_left.front.position.virtual = obj.c_add_int32(...
                obj.wheel_left.front.position.virtual, ...
                double(obj.wheel_left.front.speed.virtual) * obj.integration_multiplier);
            obj.wheel_left.rear.position.virtual = obj.c_add_int32(...
                obj.wheel_left.rear.position.virtual, ...
                double(obj.wheel_left.rear.speed.virtual) * obj.integration_multiplier);
            obj.wheel_right.front.position.virtual = obj.c_add_int32(...
                obj.wheel_right.front.position.virtual, ...
                double(obj.wheel_right.front.speed.virtual) * obj.integration_multiplier);
            obj.wheel_right.rear.position.virtual = obj.c_add_int32(...
                obj.wheel_right.rear.position.virtual, ...
                double(obj.wheel_right.rear.speed.virtual) * obj.integration_multiplier);
            process@robot_differential(obj);
        end
    end
end

function speed = speed_average(wheel)
   speed.simulation = (wheel.front.speed.simulation + wheel.rear.speed.simulation) / 2;
   speed.virtual = int32((int64(wheel.front.speed.virtual) + int64(wheel.rear.speed.virtual)) / 2);
end