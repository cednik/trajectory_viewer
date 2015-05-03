function set_speed(left, right, rear_left, rear_right)
    robot_definition = evalin('base', 'robot_definition');
    robot_local_port = evalin('base', 'robot_local_port');
    data = zeros(8 + 2 * 6, 1, 'uint8');
    data(1:3) = [204 1 2];
    convert = @(speed)typecast(swapbytes(int32(speed * robot_definition.maxSpeedValue)), 'uint8');
    cmd = 19;
    data(9:14) = [cmd 8 convert(left)];
    data(15:20) = [cmd 9 convert(-right)];
    if strcmpi(robot_definition.model, 'robot_differential4')
        data(16) = 10;
        if nargin < 3
            rear_left = left;
        end
        if nargin < 4
            rear_right = right;
        end
        data(27:32) = [cmd 9 convert(rear_left)];
        data(21:26) = [cmd 11 convert(-rear_right)];
    end
    data(4:5) = typecast(swapbytes(uint16(length(data) - 8)), 'uint8');
    u = udp('127.0.0.1', robot_local_port);
    fopen(u);
    fwrite(u, data);
    fclose(u);
    delete(u);
end
