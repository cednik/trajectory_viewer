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
    end
    properties (Dependent)
        DatagramReceivedFcn;
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
            addOptional(parser, 'pnetCheckRecBuffFreq', 25, ...
                @(v)isnumeric(v) && isreal(v) && v > 0 && v <= 1000);
            addOptional(parser, 'DatagramReceivedFcn', @(~, ~)0, @(v)isa(v, 'function_handle'));
            parse(parser, rhost, rport, varargin{:});
            obj.params = parser.Results;
            obj.datagramReceivedFcn = parser.Results.DatagramReceivedFcn;
            obj.is_open = false;
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
                    {'Forcepnet', 'pnetCheckRecBuffFreq', 'rhost', 'rport'}), ...
                    parser.Unmatched));
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
            if obj.is_open
                fclose(obj);
            end
            if obj.is_pnet
                pnet(obj.con, 'udpconnect', obj.params.rhost, obj.params.rport);
                if obj.con == -1
                    error('Udp:pnet', 'Can''t connect!');
                end
                if ~obj.read_timer.Running
                    start(obj.read_timer);
                end
            else
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
                data = pnet(obj.con, 'read', size, 'uint8');
            else
                data = fread(obj.con, size);
            end
        end
        
        function fwrite(obj, data)
            if obj.is_pnet
                pnet(obj.con, 'write', data)
                pnet(obj.con, 'writepacket');
            else
                fwrite(obj.con, data);
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
            %fprintf('process<%s>...\n', obj.Name);
            len = pnet(obj.con, 'readpacket', 65536, 'noblock');
            %fprintf('...<%s>(%d)\n', obj.Name, len);
            if len > 0 && isa(obj.datagramReceivedFcn, 'function_handle')
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
