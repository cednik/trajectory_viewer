function y = clamp(x, Min, Max)
    y = min(Max, max(Min, x));
end