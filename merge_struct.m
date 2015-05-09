function res = merge_struct(a, b)
    res = cell2struct([struct2cell(a); struct2cell(b)], [fieldnames(a); fieldnames(b)], 1);
end