function coor = model_yunimin3(enc)
    
    ecn_tick_per_rev = 760;
    wheel_diameter = 68.7; % mm
    wheels_distance = 95; % mm
    
    enc = double(enc) * pi * wheel_diameter / ecn_tick_per_rev;
    
    persistent last_enc phi;
    if isempty(last_enc)
        last_enc = enc;
        phi = 0;
        coor = [];
        return;
    end
    
    de = enc - last_enc;
    last_enc = enc;
    dphi = (de(2) - de(1)) / wheels_distance;
    if dphi ~= 0
        r0 = 0.5 * wheels_distance * sum(de) / (de(2) - de(1));
        dx = r0 * (cos(dphi) * sin(phi) + sin(dphi) * cos(phi) - sin(phi));
        dy = r0 * (sin(dphi) * sin(phi) - cos(dphi) * cos(phi) + cos(phi));
        phi = phi + dphi;
    else
        s0 = 0.5 * sum(de);
        dx = s0 * cos(phi);
        dy = s0 * sin(phi);
    end
    coor = [dx, dy, 0, 0, 0, dphi];
end