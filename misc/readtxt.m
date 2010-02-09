function [txt]=readtxt(file)
%READTXT    Reads in a text file as a single string
%
%    Usage:    txt=readtxt(file)
%
%    Description: TXT=READTXT(FILE) reads in the ascii file given by FILE
%     (the location of the file on the filesystem) as a single string TXT.
%     TXT his a row vector of characters.  End of line characters are not
%     removed.  Calling READTXT without FILE or with FILE set to '' will
%     present a graphical file selection menu.
%
%    Notes:
%
%    Examples:
%     The purpose of READTXT is to simplify the reading of text files:
%      readtxt('somefile.txt')
%
%    See also: GETWORDS

%     Version History:
%        Dec. 30, 2009 - initial version
%        Jan. 26, 2010 - add graphical selection
%        Feb.  5, 2010 - improved file checks
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated Feb.  5, 2010 at 17:25 GMT

% todo:

% check nargin
msg=nargchk(0,1,nargin);
if(~isempty(msg)); error(msg); end

% graphical selection
if(nargin<1 || isempty(file))
    [file,path]=uigetfile(...
        {'*.txt;*.TXT' 'TXT Files (*.txt,*.TXT)';
        '*.*' 'All Files (*.*)'},...
        'Select TXT File');
    if(isequal(0,file))
        error('seizmo:readtxt:noFileSelected','No input file selected!');
    end
    file=strcat(path,filesep,file);
else
    % check file
    if(~ischar(file))
        error('seizmo:readtxt:fileNotString',...
            'FILE must be a string!');
    end
    if(~exist(file,'file'))
        error('seizmo:readtxt:fileDoesNotExist',...
            'File: %s\nDoes Not Exist!',file);
    elseif(exist(file,'dir'))
        error('seizmo:readtxt:dirConflict',...
            'File: %s\nIs A Directory!',file);
    end
end

% open file for reading
fid=fopen(file);

% check if file is openable
if(fid<0)
    error('seizmo:readtxt:cannotOpenFile',...
        'File: %s\nNot Openable!',file);
end

% read in file and close
txt=fread(fid,'*char');
fclose(fid);

% row vector
txt=txt';

end