clc;
close all;
clear all;
%clear classes;

%% settings

robot_definition = select_robot('FektBot'); % FektBot / Orpheus / SixWheel (incomplete)

max_integration_loop_freq = 500; % Hz (1000 Hz is maximum)

gps_update_rate = 20; % Hz

viewer_fps = 10;

trajectory_alloc_size = min(max_integration_loop_freq, robot_definition.regulationLoopFrequency) ...
    * 60 * 15; % Fin [Hz] * seconds per min * minutes

robot_start_position = [0 0 0, 0 0 pi/2]; % X Y Z, Roll Pitch Yaw [m m m, rad rad rad]
% (6 elements row vector; if specified, X and Y are mandatory, others are optional; default zeros)

gps_home_coordinates = [49.2265908, 16.5747233]; % [latitude, longtitude] in degrees,
% increasing northwards, or eastwards respectively

gps_time_UTC_offset = -2; % not needed if MATLAB version R2014b or newer (left this field empty)
% specifies correction added to local time to get UTC. (-2 hours for CEST)

remote_ip = '127.0.0.1';
robot_remote_port = 10005;
robot_local_port = 10006;
gps_remote_port = 11000;
gps_local_port = 11001;

trajectory_line_styte = struct('color', 'm', 'lineWidth', 1);

delete_all_when_viewer_closed = true;

connect_to_gps = false;
% if true, created udp object, connected to gps_emulator, which print it's output to matlab console


%% starting simulation

robot = eval([robot_definition.model, ...
    '(robot_definition, ''maxLoopFreq'', max_integration_loop_freq, ', ...
    '''trajectory:startPosition'', robot_start_position, ', ...
    '''trajectory:AllocSize'', trajectory_alloc_size, ', ...
    '''trajectory:style'', trajectory_line_styte);']);
% simple call: robot = robot_differential(FektBot, ...);

cmd_parser = rbt_parser(robot, ...
    'udp:RemoteHost', remote_ip, 'udp:RemotePort', robot_remote_port, ...
    'udp:LocalPort', robot_local_port);

gps = gps_emulator(robot, 'fps', gps_update_rate, 'HomeCoordinates', gps_home_coordinates, ...
    'UTCoffset', gps_time_UTC_offset, 'udp:RemoteHost', remote_ip, ...
    'udp:RemotePort', gps_remote_port, 'udp:LocalPort', gps_local_port);

viewer = viewer(robot, 'fps', viewer_fps);

if delete_all_when_viewer_closed
    addlistener(viewer, 'Deleting', @(~, ~)delete(robot));
end

if connect_to_gps
    gps_listener = udp('127.0.0.1', gps_local_port, 'localPort', gps_remote_port);
    set(gps_listener, 'DatagramReceivedFcn', ...
        @(src, event)fprintf('\tFrom GPS:\n%s\n', fread(src, event.Data.DatagramLength)));
    fopen(gps_listener);
    addlistener(viewer, 'Deleting', @(~, ~)delete(gps_listener));
end
