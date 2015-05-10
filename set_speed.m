function set_speed(left, right, rear_left, rear_right)
    robot_definition = evalin('base', 'robot_definition');
    toms = @(v)v * double(robot_definition.maxSpeedValue) / robot_definition.maxSpeed;
    registers = {8, toms(left); 9, toms(-right)};
    if strcmpi(robot_definition.model, 'robot_differential4')
        if nargin < 3
            rear_left = left;
        end
        if nargin < 4
            rear_right = right;
        end
        registers{2, 1} = 10;
        registers(3:4, :) = {9, toms(rear_left); 11, toms(-rear_right)};
    end
    set_register(registers);
end
