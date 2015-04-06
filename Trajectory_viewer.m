classdef Trajectory_viewer < handle
    
    properties (SetAccess = immutable, GetAccess = private)
        gui;
    end
    
    properties (SetAccess = private)
        deleted;
    end
    
    
    methods
        %% Ctor, Dtor
        function obj = Trajectory_viewer(varargin)
            obj.deleted = false;
            parser = inputParser;
            parser.KeepUnmatched = true;
            parse(parser, varargin{:});
            cat_params = parse_categories(parser.Unmatched, {'gui'});
            cat_params.gui.DeleteFcn = @obj.delete;
            obj.gui = Gui(cat_params.gui);
        end
        
        function delete(obj)
            if obj.deleted
                return
            end
            obj.deleted = true;
            if ~obj.gui.deleted
                obj.gui.delete();
            end
        end
    end
end

function res = parse_categories(params, categories)
    for i = 1:numel(categories)
        res.(categories{i}) = struct();
    end
    names = fieldnames(params);
    for n = 1:numel(names)
        for c = 1:numel(categories)
            pos = strfind(lower(names{n}), strcat(categories{c}, ':'));
            if ~isempty(pos)
                res.(categories{c}).(...
                    names{n}(pos(1) + length(categories{c}) + 1 : end)) = params.(names{n});
                break;
            end
        end
    end
end