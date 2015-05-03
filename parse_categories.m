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
                    lower(names{n}(pos(1) + length(categories{c}) + 1 : end))) = params.(names{n});
                break;
            end
        end
    end
end