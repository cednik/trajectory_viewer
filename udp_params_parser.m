function u = udp_params_parser(params_struct)
    if isfield(params_struct, 'remotehost')
        rhost = params_struct.remotehost;
        params_struct = rmfield(params_struct, 'remotehost');
    elseif isfield(params_struct, 'rhost')
        rhost = params_struct.rhost;
        params_struct = rmfield(params_struct, 'rhost');
    else
        rhost = '';
    end
    if isfield(params_struct, 'remoteport')
        rport = params_struct.remoteport;
        params_struct = rmfield(params_struct, 'remoteport');
    elseif isfield(params_struct, 'rport')
        rport = params_struct.rport;
        params_struct = rmfield(params_struct, 'rport');
    else
        rport = '';
    end
    if isfield(params_struct, 'lport')
        params_struct.LocalPort = params_struct.lport;
        params_struct = rmfield(params_struct, 'lport');
    end
    u = udp(rhost, rport, params_struct);
end