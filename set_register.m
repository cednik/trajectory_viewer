function set_register(registers)
    robot_local_port = evalin('base', 'robot_local_port');
    force_pnet = evalin('base', 'force_pnet');
    cmd = uint8(zeros(size(registers, 1), 1));
    len = cmd;
    for i = 1:size(registers, 1)
        switch class(registers{i, 2})
            case 'int8'
                cmd(i) = 17;
                len(i) = 3;
            case 'int16'
                cmd(i) = 18;
                len(i) = 4;
            case 'int32'
                cmd(i) = 19;
                len(i) = 6;
            case 'double'
                registers{i, 2} = int32(registers{i, 2});
                cmd(i) = 19;
                len(i) = 6;
        end
    end
    data = zeros(8 + sum(len), 1, 'uint8');
    data(1:5) = [204 1 2 typecast(swapbytes(uint16(length(data) - 8)), 'uint8')];
    i = 9;
    for j = 1:length(cmd)
        l = i + len(j);
        data(i:l-1) = [cmd(j) uint8(registers{j, 1}) typecast(swapbytes(registers{j, 2}), 'uint8')];
        i = l;
    end
    u = Udp('127.0.0.1', robot_local_port, 'forcepnet', force_pnet);
    try
        fopen(u);
        fwrite(u, data);
    catch E
        fclose(u);
        delete(u);
        rethrow(E);
    end
    fclose(u);
    delete(u);
end
