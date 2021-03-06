% RUNME.m
% Run this script if you are starting from scratch.
% This script looks around your matlab environment: checks architecture,
% looks for the correct binaries and header files.
% Once everything is OK, it generates the required matlab files as well.
%
% The error messages here help you set up your system to use this toolbox.

clear all;
clc;

%Assuming this is running in the toolbox, we need to clean up.
make_mrproper;
%% Check architecture. Throw error message if not supported.

architecture = computer('arch');

switch architecture
    case 'win64'
        fprintf('You are using a 64-bit version of Matlab on Windows.\n')
        %The presence of this file determines whether the 32 or 64-bit to use.
        fp = fopen(sprintf('generated_binaries/use_64_bits'), 'w');
        fclose(fp);
    case 'glnxa64'
        %The Linux Optotrak API does not differentiate between 32 and
        %64-bits. The default is the 'OAPI' call.
        fprintf('you are using Matlab on Linux.\n')
    case 'win32'
        warning('You are using a 32-bit version of Matlab.')
    case 'maci64'
        error('The Optotrak API does not work on Mac.')
    otherwise
        fprintf('Detected achitecture is: %s\n', architecture)
        error('The optotrak API supports x86, amd64 architectures, and only Windows and Linux.')
end


%% Now, check if there is a supported compiler.

%I have moved this to an external script, so people can add their stuff if necessary.
compilers; %Check what C-compiler is available for use.

fprintf('Detected compiler is: %s\n', compiler_info.Name)

%% Check if the library and header file are there.
%You need to get these files from NDI by purchasing the API. Also, you need
%to modify the header files, consult the documentation for this.

% Separate the file list for platforms
if(isunix)
    header_file_list = {'ndhost.h', 'ndopto.h', 'ndpack.h', 'ndtypes.h'};
    binary_file_list = {'oapi64.lib', 'oapi.lib'}; % We just need the lib files for Linux.
    
else
    if(strcmp(architecture, 'win32'))
        % We are building on 32-bits. Don't look for the 64-bit files. This makes sure old APIs are working too.
        header_file_list = {'ndhost.h', 'ndopto.h', 'ndpack.h', 'ndtypes.h'};
        binary_file_list = {'oapi.dll', 'oapi.lib'};
    else
        % 64-bit system: go full-monty.
        header_file_list = {'ndhost.h', 'ndopto.h', 'ndpack.h', 'ndtypes.h'};
        binary_file_list = {'oapi64.dll', 'oapi.dll', 'oapi64.lib', 'oapi.lib'};
    end

end

fprintf('Checking for NDI''s API files...\n');
% Headers.
for(i = 1:length(header_file_list))
    %This bit checks the header files
    if(exist(sprintf('source/%s', header_file_list{i}), 'file') == 2)
        fprintf('%s found.\n', header_file_list{i})
    else
        fprintf('Missing file! -> source/%s\n', header_file_list{i})
        error('There is a missing header file. Make sure you copy them to the source directory!')
    end
end

% Binaries.
for(i = 1:length(binary_file_list))
     %...and this bit checks the binaries.
    if(exist(sprintf('bin/%s', binary_file_list{i}), 'file') == 2 || exist(sprintf('bin\\%s', binary_file_list{i}), 'file') == 3)
        fprintf('%s found.\n', binary_file_list{i})
    else
        fprintf('Missing file! -> bin/%s\n', binary_file_list{i})
        error('There is a missing binary file. Make sure you copy them to the bin directory!')
    end
end

%% If we made it this far, we can compile.
% at this point, we need to depend on platforms.

cd generated_binaries;
% This step shouldn't fail. If it does, you'll need to look at the
% compiler's output of the file concerned.
if(isunix)
    [~, warnings] = loadlibrary('/usr/lib/liboapi.so', '../source/ndopto.h', 'addheader', '../source/ndtypes.h', 'addheader', '../source/ndhost.h', 'addheader', '../source/ndpack.h', 'mfilename','api_prototypes');
else
    %Windows can also have a 32-bit version, which we have to worry about
    %If you want to see the compiler warning output, remove the semicolon
    %from the loadlibrary() statement.
    if(exist('use_64_bits', 'file') == 2)
        % Compile the 64bit stuff.
        [~, warnings] = loadlibrary('../bin/oapi64.dll', '../source/ndopto.h', 'addheader', '../source/ndtypes.h', 'addheader', '../source/ndhost.h', 'addheader', '../source/ndpack.h', 'mfilename', 'api_prototypes');
    else
        %32-bit stuff.
        [~, warnings] = loadlibrary('../bin/oapi.dll', '../source/ndopto.h', 'addheader', '../source/ndtypes.h', 'addheader', '../source/ndhost.h', 'addheader', '../source/ndpack.h', 'mfilename','api_prototypes');
    end
end
% warnings is a string, but you should also see this in the console.
fprintf('If you see this message, the compiler succeeded and you can now use loadlibrary.\nThis is a good thing.\n')
cd ..

%Okay, if we survived for this long, we should be OK for the rest.
toolbox_path = pwd;
addpath(toolbox_path); %root dir
addpath(sprintf('%s/bin', toolbox_path)); %This is where the binaries are
addpath(sprintf('%s/api_functions', toolbox_path)); %This allows you to conveniently all the functions as described in NDI's manual
addpath(sprintf('%s/convenience', toolbox_path)); %This is where some pre-made convenience functions are located.
addpath(sprintf('%s/generated_binaries', toolbox_path)); %This is only required for the function prototypes
addpath(sprintf('%s/plotting', toolbox_path)); %Added some plotting scripts
msgbox('The toolbox has been to the Matlab path. To make this permanent, click ''yes'' at the next prompt if it pops up.', 'Toolbox setup successful');



%% compile helper functions written in C.
%Add the names of the C files you want to compile during toolbox set-up.
fprintf('Now compiling the helper functions...\n')
files_to_compile = {'DataGetLatest3D_as_array.c', 'DataGetNext3D_as_array.c', 'DataGetLatestTransforms2_as_array.c', 'DataGetNextTransforms2_as_array.c', 'RigidBodyAddFromFile_euler.c', 'optotrak_tell_me_what_went_wrong.c', 'optotrak_convert_raw_file_to_position3d_array.c', 'optotrak_convert_raw_file_to_rigid_euler_array.c', 'optotrak_align_coordinate_system.c', 'optotrak_register_system_static.c', 'optotrak_register_system_dynamic.c', 'DataReceiveLatest3D_as_array.c', 'DataReceiveLatestTransforms2_as_array.c'};
cd generated_binaries
for(i = 1:length(files_to_compile))
    fprintf('\nCompiling %s:\n', files_to_compile{i});
    file_string = sprintf('../source/%s', files_to_compile{i});
    
    % if we made it this far, the rest of the stuff compiled, and
    % everything is set up for the platform it will run on.
    if(isunix)
        %Linux needs a different treatment.
        compiler_string = sprintf('mex -v %s CC_3RD_PARTY_LIBS=''../bin/liboapi.so'' %s', compiler_flags, file_string)
        eval(compiler_string);

    else 
        %compiler_flags is set in compilers.m, and we always append to the default one, instead of replacing it.
        if(new_or_old)
            compiler_string = sprintf('mex -v COMPFLAGS="$COMPFLAGS %s" %s -l../bin/oapi64.lib', compiler_flags, file_string);
            eval(compiler_string);
        else
            if(verLessThan('Matlab', '8.6'))
                %For 32-bit Matlab R2015a or earlier, the compiler string is totally different. I tested this with R2015a and VS2013.
                compiler_string = sprintf('mex -v COMPFLAGS="$COMPFLAGS %s" %s -L..\\bin -loapi %s', compiler_flags, ['-I"', toolbox_path, '\source"'], file_string  );
            else
                % For R2015b, and I have tested this with VS2015.
                compiler_string = sprintf('mex -v COMPFLAGS="$COMPFLAGS %s" %s -l../bin/oapi.lib', compiler_flags, file_string);
            end
            % compile!
            eval(compiler_string);
        end
    end
    fprintf('Compilation of %s completed successfully.\n', files_to_compile{i})
    pause(0.5); %wait for the compilation process to finish.
end
cd(toolbox_path);
fprintf('Compiling the mex files didn''t fail!\n');

%unload library.
optotrak_kill;

%savepath; %Make these permanent.
fprintf('Toolbox path added, all done!\n')