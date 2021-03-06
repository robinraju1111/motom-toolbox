% This script generates a new camera file, which will hold the new
% calibration data.
%
% Prerequisities:
% -A working rigid body (file and markers)
% -10 seconds of recording with static markers
%

%How this works:
% 1., We record 10 seconds of stationary markers using the factory calibration, and save the raw data file.
% 2., We load the rigid body file that corresponds with the markers, and generate the new camera file to using the API.
% 3., In everything you run, you need to use the newly generated camera file.


%Destroy everything.
clear all;
clc;
%temporarily
system('del *.log');
system('del *.dat');


%original_camera_file = 'Registered_2017-09-24_16-08-43'; %initially.
original_camera_file = 'standard'; %initially.
config_file = 'alignment_settings'; %I tailored this for my 10 marker setup. Change it to your own. Make sure all markers are visible and bright enough.
recording_file = sprintf('recording_used_for_alignment_%s.dat', datestr(now, 'yyyy-mm-dd_HH-MM-SS')); %In this case, the local directory.
rigid_body_file = 'asztal'; %This can be in C:\ngidital\rigid, or local. I chose local.
new_camera_file = sprintf('Aligned_%s.cam', datestr(now, 'yyyy-mm-dd_HH-MM-SS')); %Genreate the new camera file
logfile_name = sprintf('Aligned_%s.log', datestr(now, 'yyyy-mm-dd_HH-MM-SS')); %Genreate the new camera file


%% Step 0. Initialise. Declare useful variables here so I can check what I am meddling with.
optotrak_startup; %Do the reset dance. Make the system beep.
optotrak_set_up_system(original_camera_file, config_file); %Load the settings.
% fail = RigidBodyAddFromFile_euler(0, 1, rigid_body_file); % Load a rigid body as well.
% if(fail)
%     optotrak_tell_me_what_went_wrong;
%     error('Couldn''t add the specified rigid body.')
% end


% We need to know how the system is initialised. It's in the config file,
% but let's load it here.
fail = 0;
sensors = 0;
odaus = 0;
rigid_bodies = 0;
markers = 0;
frame_rate = 0;
marker_frequency = 0;
threshold = 0;
gain = 0;
are_we_streaming = 0;
duty_cycle = 0;
voltage = 0;
collection_time = 0;
pretrigger_time = 0;
flags = 0;


[fail, sensors, odaus, rigid_bodies, markers, frame_rate, marker_frequency, threshold, gain, are_we_streaming, duty_cycle, voltage, collection_time, pretrigger_time, flags] = OptotrakGetStatus(sensors, odaus, rigid_bodies, markers, frame_rate, marker_frequency, threshold, gain, are_we_streaming, duty_cycle, voltage, collection_time, pretrigger_time, flags);
number_of_frames = frame_rate * collection_time;
if(mod(number_of_frames, 1))
    optotrak_kill;
    error('According to the system, the frame rate and the collection time do not yield a round number!')
end

%% Step 1.

[fail, ~] = DataBufferInitializeFile(0, recording_file);
if(fail)
    optotrak_tell_me_what_went_wrong;
    error('Couldn''t open file. Have you got permissions?')
end
fprintf('Data buffer file created.\n')
OptotrakActivateMarkers();
%Do a countdown.
fprintf('Waiting 5 seconds. Don''t move anything, and stay out of the way so the camera can see all the markers!\n')
pause(2);
fprintf('3\n')
pause(1);
fprintf('2\n')
pause(1);
fprintf('1\n')
pause(1);
fprintf('RECORDING NOW!\n')
DataBufferStart(); %Begin recording
%While recording, monitor coordinates. This is not going to be accurate at high frame rates.
%It doesn't matter, it's for indication only.
coordinates = zeros(number_of_frames, markers*3);
framecounter = zeros(number_of_frames, 1);
for(i=1:number_of_frames)
    [~, ~, coordinates(i, :), ~] = DataGetLatest3D_as_array();
    if(~mod(i, number_of_frames/10))
        fprintf('.')
    end
end


fprintf('\n')
optotrak_stop_buffering_and_write_out; %save the buffer to the data file we allocated.
OptotrakDeActivateMarkers();

% Now do some sanity check on the data.
if(isnan(mean(mean(coordinates))))
    %If there is an invisible marker, we need to let the world know
    warning('The collected data has markers that are not visible during the recording. Make sure everything is visible all the time!')
else
    fprintf('All markers were visible throughout the recording.\n')
end
optotrak_kill;
pause(3);

%% Step 2.
optotrak_load_lib; %This just loads the libraries, without touching the system.

% Call our helper function.
[fail, rms_error] = optotrak_align_coordinate_system(original_camera_file,recording_file,sprintf('%s.rig', rigid_body_file),new_camera_file,logfile_name);
if(fail)
    optotrak_tell_me_what_went_wrong;
    optotrak_kill;
    error('Calibration failed.')
end

fprintf('Error introduced by applying new coordinate system: %.3f mm.\n', rms_error)

%Finito.


