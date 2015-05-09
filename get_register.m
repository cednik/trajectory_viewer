function values = get_register(indexes)
    robot_local_port = evalin('base', 'robot_local_port');
    robot_remote_port = evalin('base', 'robot_remote_port');
    force_pnet = evalin('base', 'force_pnet');
    data = zeros(8 + 2 * length(indexes), 1, 'uint8');
    data(1:5) = [204 1 2 typecast(swapbytes(uint16(length(data) - 8)), 'uint8')];
    for i = 1:length(indexes)
        data(7+2*i:8+2*i) = [3, uint8(indexes(i))];
    end
    u = Udp('127.0.0.1', robot_local_port, 'localport', robot_remote_port, ...
        'forcepnet', force_pnet, 'Timeout', 10);
    try
        fopen(u);
        fwrite(u, data);
        ps = pause('on');
        pause(0.1);
        pause(ps);
        data = uint8(fread(u, 8 + 6 * length(indexes)));
    catch E
        fclose(u);
        delete(u);
        rethrow(E);
    end
    fclose(u);
    delete(u);
    if length(data) < 8
        warning('RBTPARSER:InvalidPacket', ...
            'Packet is toot short to contain correct RBT header (has only %d bytes).', ...
            length(data));
        return;
    end
    if data(1) ~= 204
        warning('RBTPARSER:UnsupportedProtocol', ...
            'Protocol with ID 0x%02X is not supported.', ...
            data(1));
        return;
    end
    reclen = swapbytes(typecast(data(4:5), 'uint16'));
    if (reclen + 8) ~= length(data)
        warning('RBTPARSER:InvalidLength', ...
            ['Packet length specified in RBT header does not match received packet length.\n' ...
             '\tDeclared %d, but received only %d bytes.'], reclen, length(data) - 8);
        return;
    end
    i = 9;
    o = 1;
    values = cell(length(indexes), 2);
    while i <= length(data)
        switch(data(i))
            case 5
                [i, v] = extract_value(data, i, 1);
            case 6
                [i, v] = extract_value(data, i, 2);
            case 7
                [i, v] = extract_value(data, i, 4);
            otherwise
                warning('RBTPARSER:UnknownCommand', ...
                    ['Received invalid command 0x%02X (byte %d).\n' ...
                     '\tParsing aborted.'], data(i), i);
                values = values(1:o-1);
                break;
        end
        values(o, :) = v;
        o = o + 1;
    end
    if i == length(data) + 2
        values = values(1:o-2);
    end
end

function [i, v] = extract_value(data, i, len)
    data_types = {'int8', 'int16', '', 'int32'};
    if (i + 1 + len) > length(data)
        warning('RBTPARSER:NotEnoughtArguments', ...
            ['There are not enought arguments for last command 0x%02X\n' ...
             '\t(Expected %d bytes, but only %d bytes left in packet).'], ...
            data(i), len, length(data) - i - 1);
        i = length(data) + 2;
        v = {-1, []};
    else
        v = {data(i+1), swapbytes(typecast(data(i+2:i+1+len), data_types{len}))};
        i = i + 2 + len; 
    end
end