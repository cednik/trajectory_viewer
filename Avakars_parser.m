classdef Avakars_parser < handle
    properties(SetAccess = immutable)
        robot_model_fcn;
    end
    properties(SetAccess = private)
        state;
        cmd;
        len;
        data;
        plot_fcn;
    end
    methods
        function obj = Avakars_parser(robot_model_fcn)
            obj.robot_model_fcn = robot_model_fcn;
            obj.state = 0;
            obj.cmd = 0;
            obj.len = 0;
            obj.data = uint8(zeros(16, 1));
            obj.plot_fcn = @(~)(0);
        end
        
        function delete(obj)
        end
        
        function set_plot_fcn(obj, fcn)
            obj.plot_fcn = fcn;
        end
        
        function clear(obj)
            obj.state = 0;
        end
        
        function process(obj, com)
            if com.BytesAvailable == 0
                return;
            end
            rec = fread(com, com.BytesAvailable);
            for i = 1:length(rec)
                byte = uint8(rec(i));
                switch obj.state
                    case 0
                        if byte ~= 128
                            continue;
                        end
                        obj.state = 1;
                    case 1
                        obj.cmd = bitshift(bitand(byte, uint8(240)), -4);
                        obj.len = bitand(byte, uint8(15));
                        if obj.len == 0
                            cmd_dispatch(obj);
                        else
                            obj.state = 2;
                        end
                    otherwise
                        obj.state = obj.state + 1;
                        obj.data(obj.state - 2) = byte;
                        if obj.state >= (obj.len + 2)
                            cmd_dispatch(obj);
                        end
                end
            end
        end
        
        function cmd_dispatch(obj)
            obj.state = 0;
            switch obj.cmd
                case 2
                    process_encoders(obj);
            end
        end
        
        function process_encoders(obj)
            if obj.len ~= 8
                warning('AvakarsParser:TooFewBytes', ...
                    'Too few bytes for encoders received (only %d, should by 8)', obj.len);
                return;
            end
            obj.plot_fcn(obj.robot_model_fcn(typecast(obj.data(1:8), 'int32')));
        end
    end
end
