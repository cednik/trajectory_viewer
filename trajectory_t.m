classdef trajectory_t < handle
    
    properties (SetAccess = private)
        deleted;
        alloc_size;
        
        Coor; % private internal storage
        coor; % use this (via getter)
        points;
        updated;
        style;
    end
    
    
    methods
        %% Ctor
        function obj = trajectory_t(varargin)
            obj.deleted = false;
            parser = inputParser;
            addOptional(parser, 'Style', {}); % FIX-ME: add checking
            addOptional(parser, 'StartPosition', {}); % FIX-ME: add checking
            addOptional(parser, 'AllocSize', 2^20, @(v)(v>0)&&mod(v,1)==0);
            parse(parser, varargin{:});
            obj.alloc_size = parser.Results.AllocSize;
            init(obj, parser.Results.Style, parser.Results.StartPosition);
        end
        
        function delete(obj)
            if obj.deleted
                return
            end
            obj.deleted = true;
        end
        
        %% modifiers
        function [robot_coor] = add_point(obj, coor, absolute)
            if nargin < 4
                absolute = false;
            end
            if size(obj.Coor, 1) == obj.points %% realloc if full
                obj.Coor = [obj.Coor; NaN(size(obj.Coor))];
            end
            if length(coor) == 2
                coor = [coor, 0];
            end
            abs_rot = absolute;
            if length(coor) == 3
                abs_rot = true;
                if absolute
                    [r, p, y] = calc_orientation(obj);
                else
                    [r, p, y] = calc_orientation(obj, coor);
                end
                coor = [coor, r, p, y];
            elseif length(coor) ~= size(obj.Coor, 2)
                coor = [coor, zeros(1, size(obj.Coor, 2) - length(coor))];
            end
            if absolute
                obj.points = obj.points + 1;
                obj.Coor(obj.points, :) = coor;
                robot_coor = coor;
            else
                if ~any(coor)
                    robot_coor = obj.Coor(obj.points, :);
                    return;
                end
                obj.points = obj.points + 1;
                if abs_rot
                    obj.Coor(obj.points, 1:3) = coor(1:3) + obj.Coor(obj.points - 1, 1:3);
                    obj.Coor(obj.points, 4:6) = coor(4:6);
                else
                    obj.Coor(obj.points, :) = obj.Coor(obj.points - 1, :) + coor;
                end
                robot_coor = obj.Coor(obj.points, :);
            end
            obj.updated = true;
        end
        
        function [robot_coor] = add_point_rel_fast(obj, coor)
            if size(obj.Coor, 1) == obj.points %% realloc if full
                obj.Coor = [obj.Coor; NaN(size(obj.Coor))];
            end
            obj.points = obj.points + 1;
            obj.Coor(obj.points, :) = obj.Coor(obj.points - 1, :) + coor;
            robot_coor = obj.Coor(obj.points, :);
            obj.updated = true;
        end
        
        function clear(obj)
            init(obj, obj.style, obj.Coor(1, :));
        end
            
        
        function t = get.coor(obj)
            t = obj.Coor(1:obj.points, :);
            obj.updated = false;
        end
    end
    
    methods (Access = private)
        function [r, p, y] = calc_orientation(obj, dif)
            if nargin < 2 || isempty(dif)
                dif = diff(obj.Coor(obj.points-1:obj.points, 1:3));
            end
            r = 0;
            p = atan2(sqrt(sum(dif(1:2).^2)), dif(3)) - pi/2;
            if dif(1) == 0 && dif(2) == 0
                y = obj.Coor(l-1, 6);
            else
                y = atan2(dif(2), dif(1));
            end
        end
        
        function init(obj, style, first)
            obj.Coor = NaN(obj.alloc_size, 6);
            obj.points = 1;
            obj.updated = true;
            if nargin < 2 || isempty(style)
                style = 'm';
            end
            obj.style = style;
            if nargin < 3 || isempty(first)
                obj.Coor(1, :) = zeros(1, size(obj.Coor, 2));
            else
                obj.Coor(1, :) = first;
            end
        end
    end
end
