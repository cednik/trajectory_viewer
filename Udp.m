classdef Udp < handle
    properties (SetAccess = immutable)
        is_pnet;
        params;
        read_timer;
        Name;
    end
    properties (SetAccess = private)
        deleted;
        con;
        is_open;
        datagramReceivedFcn;
        rx_buff;
        timeout;
    end
    properties (Dependent)
        DatagramReceivedFcn;
        Timeout;
    end
    methods
        function obj = Udp(rhost, rport, varargin)
            obj.deleted = false;
            parser = inputParser;
            parser.KeepUnmatched = true;
            check_port = @(v)isnumeric(v) && isreal(v) && v > 0 && v < 65536;
            addRequired(parser, 'rhost', @ischar);
            addRequired(parser, 'rport', check_port);
            addOptional(parser, 'LocalPort', 10000, check_port);
            addOptional(parser, 'Forcepnet', false, @islogical);
            addOptional(parser, 'pnetCheckRecBuffFreq', 100, ...
                @(v)isnumeric(v) && isreal(v) && v > 0 && v <= 1000);
            addOptional(parser, 'DatagramReceivedFcn', @(~, ~)0, @(v)isa(v, 'function_handle'));
            addOptional(parser, 'Timeout', inf, @(v)isnumeric(v) && isreal(v) && v >= 0);
            parse(parser, rhost, rport, varargin{:});
            obj.params = parser.Results;
            obj.datagramReceivedFcn = parser.Results.DatagramReceivedFcn;
            obj.is_open = false;
            obj.rx_buff = [];
            obj.timeout = parser.Results.Timeout;
            if ~is_toolbox_available('Instrument Control Toolbox') || parser.Results.Forcepnet
                obj.is_pnet = true;
                obj.read_timer = timer(...
                    'BusyMode', 'drop', ...
                    'ExecutionMode', 'fixedRate', ...
                    'Period', 1 / parser.Results.pnetCheckRecBuffFreq, ...
                    'TimerFcn', @(~, ~)process_rx(obj), ...
                    'Name', sprintf('Receiving timer of Udp(%s:%d)', ...
                    parser.Results.rhost, parser.Results.rport));
                obj.con = pnet('udpsocket', obj.params.LocalPort);
            else
                obj.is_pnet = false;
                obj.con = udp(parser.Results.rhost, parser.Results.rport, ...
                    merge_struct(rmfield(parser.Results, ...
                    {'Forcepnet', 'pnetCheckRecBuffFreq', 'rhost', 'rport', 'Timeout'}), ...
                    parser.Unmatched));
                if obj.timeout ~= inf
                    set(obj.con, 'Timeout', obj.timeout);
                end
            end
            obj.Name = sprintf('Udp<%s>(%s:%d)', conditional(obj.is_pnet, 'pnet', 'udp'), ...
                parser.Results.rhost, parser.Results.rport);
            if obj.is_pnet
                start(obj.read_timer);
            end
        end
        
        function delete(obj)
            if obj.deleted
                return
            end
            obj.deleted = true;
            if obj.is_pnet
                stop(obj.read_timer);
            end
            fclose(obj);
            if ~obj.is_pnet
                delete(obj.con);
            end
        end
        
        function fopen(obj)
            if ~obj.is_pnet
                if obj.is_open
                    fclose(obj);
                end
                fopen(obj.con);
            end
            obj.is_open = true;
        end
        
        function fclose(obj)
            if obj.is_open
                if obj.is_pnet
                    stop(obj.read_timer);
                    pnet(obj.con, 'close');
                else
                    fclose(obj.con);
                end
                obj.is_open = false;
            end
        end
        
        function data = fread(obj, size)
            if obj.is_pnet
                running = obj.read_timer.Running;
                if strcmp(running, 'on')
                    stop(obj.read_timer);
                end
                t = clock();
                while length(obj.rx_buff) < size
                    process_rx(obj);
                    if etime(clock(), t) > obj.timeout
                        size = length(obj.rx_buff);
                        break;
                    end
                end
                data = obj.rx_buff(1:size);
                obj.rx_buff = obj.rx_buff(size+1:end);
                if strcmp(running, 'on')
                    start(obj.read_timer);
                end
            else
                data = fread(obj.con, size);
            end
        end
        
        function len = fwrite(obj, data)
            if obj.is_pnet
                pnet(obj.con, 'write', data);
                len = pnet(obj.con, 'writepacket', obj.params.rhost, obj.params.rport);
            else
                fwrite(obj.con, data);
                len = length(data);
            end
        end
        
        
        function fcn = get.DatagramReceivedFcn(obj)
            if obj.is_pnet
                fcn = obj.datagramReceivedFcn;
            else
                fcn = get(obj.con, 'DatagramReceivedFcn');
            end
        end
        
        function set.DatagramReceivedFcn(obj, fcn)
            if obj.is_pnet
                obj.datagramReceivedFcn = fcn;
            else
                set(obj.con, 'DatagramReceivedFcn', fcn);
            end
        end
        
        function t = get.Timeout(obj)
            if obj.is_pnet
                t = obj.timeout;
            else
                t = get(obj.con, 'Timeout');
            end
        end
        
        function set.Timeout(obj, t)
            if obj.is_pnet
                obj.timeout = t;
            else
                set(obj.con, 'Timeout', t);
            end
        end
        
        
        function v = get(obj, name)
            v = obj.(name);
        end
        
        function set(obj, varargin)
            for i = 1:2:numel(varargin)
                obj.(varargin{i}) = varargin{1 + 1};
            end
        end
    end
    
    methods (Access = private)
        function process_rx(obj)
            len = pnet(obj.con, 'readpacket', 65536, 'noblock');
            if len == -1
                pnet(obj.con, 'close');
                obj.con = pnet('udpsocket', obj.params.LocalPort);
            end
            if len > 0
                i = length(obj.rx_buff);
                obj.rx_buff(i+1:i+len) = pnet(obj.con, 'read', len, 'uint8');
                if isa(obj.datagramReceivedFcn, 'function_handle')
                    [ip, port] = pnet(obj.con,'gethost');
                    ip = sprintf('%d.%d.%d.%d', ip(1), ip(2), ip(3), ip(4));
                    obj.datagramReceivedFcn(obj, struct(...
                        'Type', 'DatagramReceived', ...
                        'Data', struct( ...
                            'AbsTime', clock(), ...
                            'DatagramAddress', ip, ...
                            'DatagramLength', len, ...
                            'DatagramPort', port)));
                end
            end
        end
    end
    
    methods (Static)
        function init_pnet(force)
            if nargin < 1
                force = false;
            end
            if (is_toolbox_available('Instrument Control Toolbox') && ~force) ...
                    || exist('pnet') == 3
                return;
            end
            try
                mex -O pnet.c ws2_32.lib -DWIN32
            catch ME
                rethrow(addCause(ME, MException('Udp:pnet:compilation', ...
                    ['Unable to compile pnet, bacouse following reasons. ', ...
                     'Please try to compile manually - read the header of pnet.c'])));
            end
        end
    end
end
