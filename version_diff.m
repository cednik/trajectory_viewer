function d = version_diff(v)
% VERSION_DIFF Return difference between current and passed in Matlab
%  version.
% d = VERSION_DIFF(v)
%  v is string with Matlab version in format 'R2011a'.
%  Result is positive if current Matlab version is newer then
%   specified, zero, if they equals and negative otherwise.

    d = parse(version('-release')) - parse(v);
    function n = parse(v)
        if ~ischar(v)
            error('Invalid vesrion string (not a string).');
        end
        if v(1) == 'R'
            v = v(2:end);
        end
        if length(v) ~= 5
            error('Invalid vesrion string (wrong length).');
        end
        y = str2double(v(1:end-1));
        if isnan(y)
            error('Invalid vesrion string (year is not a number).');
        end
        hy = v(end) - 'a';
        if hy < 0 || hy > 1
            error('Invalid vesrion string(invalid last char).');
        end
        n = y * 2 + hy;
    end
end