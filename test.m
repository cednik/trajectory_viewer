close all;
clear all;
% robot: (symbol) normalised, centered at [0 0 0], aligned with X axis
% robotSize: size of the greatest number of robot symbol in units
%  returned by robot_model_function (model_yunimin3 here, e.g. mm)
% minRobotSize: minimium robot size, relative to display (axes). Value in
%  range (0; 1>. When real robot size is too smal relative to display size,
%  robot is upscaled to specified percentage of display size;
yunimin = {...
    {[1, 1; 1, -1; -1, -1; -1, 1; 1, 1], struct('LineWidth', 2)}; ...
    {[-0.8,  1; 0.8,  1], struct('Color', 'r', 'LineWidth', 4)}; ...
    {[-0.8, -1; 0.8, -1], struct('Color', 'g', 'LineWidth', 4)}; ...
    [-1, 0; 1, 0]; ...
    [0.5, 0.5; 1, 0; 0.5, -0.5]; ...
    [0, -0.2; 0, 0.2]; ...
    0.14*[cos(linspace(0, 2*pi, 16)'), sin(linspace(0, 2*pi, 16)')]};

v = Trajectory_viewer(Avakars_parser(@model_yunimin3), ...
    'gui:robot', yunimin, 'gui:robotSize', 50, 'gui:minRobotSize', 0.05);