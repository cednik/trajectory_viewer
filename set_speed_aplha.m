function set_speed_aplha(speed, alpha)
    robot_definition = evalin('base', 'robot_definition');
    registers = {8, speed * double(robot_definition.maxSpeedValue) / robot_definition.maxSpeed; ...
        9, alpha * double(robot_definition.maxAlphaValue) / robot_definition.maxAlpha};
    set_register(registers);
end