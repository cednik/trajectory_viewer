classdef rbt_parser < handle
    properties (Constant = true)
        data_types = {'int8', 'int16', '', 'int32'};
        max_datagram_length = 8 + 1464
    end
    properties (SetAccess = immutable)
        robot;
        connection;
    end
    properties (SetAccess = private)
        deleted;
        responce_buffer;
    end
    methods
        function obj = rbt_parser(robot, varargin)
            obj.deleted = false;
            obj.robot = robot;
            addlistener(robot, 'Deleting', @(~, ~)delete(obj));
            obj.responce_buffer = uint8(zeros(obj.max_datagram_length, 1));
            obj.responce_buffer(1:3) = [204 1 2];
            parser = inputParser;
            parser.KeepUnmatched = true;
            parse(parser, varargin{:});
            cat_params = parse_categories(parser.Unmatched, {'udp'});
            obj.connection = udp_params_parser(cat_params.udp);
            set(obj.connection, 'DatagramReceivedFcn', @(~, event)process(obj, event));
            fopen(obj.connection);
        end
        
        function delete(obj)
            if obj.deleted
                return
            end
            obj.deleted = true;
            fclose(obj.connection);
            delete(obj.connection);
        end
        
        function process(obj, event)
            data = uint8(fread(obj.connection, event.Data.DatagramLength));
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
            o = uint16(9);
            while i <= length(data)
                switch(data(i))
                    case 1
                        [i o] = get_register(obj, data, i, o, 1);
                    case 2
                        [i o] = get_register(obj, data, i, o, 2);
                    case 3
                        [i o] = get_register(obj, data, i, o, 4);
                    case 17
                        i = set_register(obj, data, i, 1);
                    case 18
                        i = set_register(obj, data, i, 2);
                    case 19
                        i = set_register(obj, data, i, 4);
                    otherwise
                        warning('RBTPARSER:UnknownCommand', ...
                            ['Received invalid command 0x%02X (byte %d).\n' ...
                             '\tParsing aborted.'], data(i), i);
                        break;
                end
            end
            if o ~= 9
                send_output_buffer(obj, o);
            end
        end
    end
    
    %% internal
    methods (Access = protected, Hidden = true)
        function i = set_register(obj, data, i, len)
            if (i + 1 + len) > length(data)
                warning('RBTPARSER:NotEnoughtArguments', ...
                    ['There are not enought arguments for last command 0x%02X\n' ...
                     '\t(Expected %d bytes, but only %d bytes left in packet).'], ...
                    data(i), len, length(data) - i - 1);
                i = length(data) + 1;
            else
                set_register(obj.robot, data(i+1), swapbytes(typecast(data(i+2:i+1+len), ...
                    obj.data_types{len})));
                i = i + 2 + len; 
            end
        end
        
        function [i o] = get_register(obj, data, i, o, len)
            if (o + 2 + len) > obj.max_datagram_length
                send_output_buffer(obj, o);
                o = 9;
            end
            if (i + 1) > length(data)
                warning('RBTPARSER:NotEnoughtArguments', ...
                    ['There are not enought arguments for last command 0x%02X\n' ...
                     '\t(Expected 1 byte, but no one left in packet).'], data(i));
                i = length(data) + 1;
            else
                obj.responce_buffer(o:o+1+len) = [4 + data(i), data(i+1), ...
                    typecast(swapbytes(get_register(obj.robot, data(i+1), obj.data_types{len})), ...
                    'uint8')];
                i = i + 2;
                o = o + 2 + len;
            end
        end
        
        function send_output_buffer(obj, o)
            obj.responce_buffer(4:5) = typecast(swapbytes(o - 9), 'uint8');
            fwrite(obj.connection, obj.responce_buffer(1:o-1));
        end
    end
end
