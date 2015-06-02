function [nhit, nmiss, nfalsea, rt] = MyClock(varargin)
% function MYCLOCK
% [hit, miss, falsealarm, rt] = MyClock([,datein = now] [, sizein = 500])
% parameters:
% datein: 可选参数。程序开始时钟表的时间。格式为yyyy-mm-dd hh:mm:ss，是一个字符串
%   默认为当前时间。
% sizein: 可选参数。表盘直径，单位为像素。默认为500
% hit、miss、falsealarm：返回这三种反应的次数
% rt：所有hit条件下的平均反应时
% by wenkai

%% 需要提高的地方!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
% 1.使用try catch
%% define variables
%nargin = 0; % for debugging
if nargin == 0
    startt = GetSecs;
    datein = datenum(clock);
    sizein = 500;
elseif nargin == 1
    startt = GetSecs;
    if ~isempty(varargin{1})
        datein = datenum(varargin{1},'yyyy-mm-dd HH:MM:SS');
    else
        datein = datenum(clock);
    end
    sizein = 500;
elseif nargin == 2;
     startt = GetSecs;
    if ~isempty(varargin{1})
        datein = datenum(varargin{1},'yyyy-mm-dd HH:MM:SS');
    else
        datein = datenum(clock);
    end
    if ~isempty(varargin{2})        
        sizein = varargin{2};
    else
        sizein = 500;
    end
end
datenowold = datein;
%colors;  % 绘图中使用的颜色
bkcolor = [128, 128, 128]; % 背景颜色
bkcolorlighter = [200, 200, 200]; % 更亮的背景颜色
sizeother = 140;% 表盘下方文字所需的显示空间的二倍。单位：像素
totaltime = 90; %程序运行的最长时间
rtall = 0;  % 记录反应时
nhit = 0;
nmiss = 0;
nfalsea = 0;
penWidthDefault = 0.01 * sizein;

% beep
beepdur = 0.5;
beepfreq = 1000;
samplerate = 16000;
beep = MakeBeep(beepfreq, beepdur, samplerate);
gatedur = 0.05;
gate1 = 0:1/(gatedur * samplerate - 1):1;
gate2 = 1:-1/(gatedur * samplerate - 1):0;
envelope = [gate1, ones(1, length(beep) - length(gate1) - length(gate2)), gate2];
beep = beep .* envelope;
% 缓存报时数据，以避免程序中途读取硬盘带来的卡顿
for i = 1:60
    sfilename = sprintf('./Supplementary/m/%02d.mp3',i - 1);
    [minutes{i,1},minutes{i,2}] = audioread(sfilename);
end
for i = 1:24
    sfilename = sprintf('./Supplementary/h/%02d.mp3',i - 1);
    [hours{i,1},hours{i,2}] = audioread(sfilename);
end
% 变色
% 时间均以GetSecs为参照
% LastActionTime = 0;% 上次被试反应或漏报的时间
% LastChangedTime = 0; % 上次注视点变色的时间
% NextChangeTime = 0; % 下次注视点变色时间
% NeedChange = 1;  % 是否需要变色
fixdotcolor1 = [0, 0, 0];% 注视点变色之前的颜色
fixdotcolor2 = [0, 255, 0];   % 注视点变色之后的颜色
waitstatus = 31;  % 指示目前实验的状态  0: 未定义    1： 注视点是绿色    2：注视点由绿色变回黑色，被试尚未反应
    % 31：被试已经按键反应或2s时间已过,且未确定下次变色时间   32：被试已经按键反应或2s时间已过,
    % 且下次变色时间已确定
timeout = 2;   % 被试的最长反应时间
Greendur = 1; % 绿色的持续时间
oldkcspace = 0; % 上一次循环时是否按住了空格键
%% debugger parameters
FlipTimestampold = startt;
fps = 0;

%% initilize PTB
KbName('UnifyKeyNames'); % 统一映射键盘扫描码
ListenChar(1);
escape = KbName('escape');
space = KbName('space');
windowsize = [0, 0, sizein + sizeother, sizein + sizeother];
windowcenter = zeros(1,2);
[windowcenter(1), windowcenter(2)] = RectCenter(windowsize);
% 准备 psychportaudio
InitializePsychSound;
pahandle = PsychPortAudio('Open',[],[],[],samplerate);
Screen('Preference', 'SkipSyncTests', 1);  % 跳过同步测验
[wPtr,~] = Screen('OpenWindow',0,bkcolor,windowsize);  % !!!!!需要先查明屏幕使用情况

% 退出程序逻辑
while(1) %%%%%%%%%%%%表盘
[~, secs, kC] = KbCheck(-1); % 查询所有键盘的按键情况
%[~,kC2] = KbPressWait(-1);
nowGS = GetSecs;  % GetSecs中得到的当前时间
if kC(escape) || (nowGS - startt>totaltime)
    break;
end
% 取现在应该的时间

%%  检测按键反应
if waitstatus == 1 || waitstatus == 2
    % 先排除超时的情况
    if nowGS > ChangedToGreenTime + timeout
        waitstatus = 31;
        nmiss = nmiss + 1;
    else
        if (kC(space)) &&  (~oldkcspace)
            nhit = nhit + 1;
            rtall(nhit) = secs - ChangedToGreenTime;
            waitstatus = 31;
        end
    end
    % 清空事件队列
    FlushEvents();
else 
    if (kC(space)) && (~oldkcspace)
        nfalsea = nfalsea + 1;
    end
end
oldkcspace = kC(space);


%% 画表盘
% 先画背景
if kC(space)
    Screen('FillRect', wPtr, bkcolorlighter, windowsize);
else
    Screen('FillRect', wPtr, bkcolor, windowsize);
end

ovalcolor = [255, 255, 255];  % 采用白色填充
[ovalrect,~,~] = CenterRect([0, 0, sizein, sizein], windowsize);
Screen('FillOval', wPtr, ovalcolor, ovalrect);

% 表盘上的刻度线
% 
majortickcolor = [255, 0, 0]; % 整小时刻度线颜色
majortickwidth = 0.005 * sizein + 2;  % 整小时刻度线宽度，为表盘直径的0.5%+2像素
majorticklongth = 0.1 * sizein;  % 整小时刻度线长度，为表盘直径的10%
minortickcolor = [0, 0, 0]; % 分钟刻度线颜色
minortickwidth = 0.002 * sizein + 1;  % 分钟刻度线粗细，为表盘直径的0.2%+1像素
minorticklongth = 0.07 * sizein;  % 分钟刻度线长度，为表盘直径的 7%
majornumcolor = [0, 255, 0];  % 主要数字字体颜色
majornumsize = 0.08 * sizein; % 主要数字字体大小
minornumcolor = [0, 0, 0];  % 次要数字字体颜色
minornumsize = 0.05 * sizein; % 次要数字字体大小
% 先画小刻度线
sita = 0: 2 * pi / 60 : 2 * pi;
x1 = sizein / 2 * cos(sita) + windowcenter(1);
y1 = sizein / 2 * sin(sita) + windowcenter(2);
x2 = (sizein / 2 - minorticklongth) * cos(sita) + windowcenter(1);
y2 = (sizein / 2 - minorticklongth) * sin(sita) + windowcenter(2);
for i = 1:60
    if mod(i,5) ~= 1
        Screen('Drawline', wPtr, minortickcolor, y1(i), x1(i), y2(i), x2(i), minortickwidth);
    end
end
sita = 0:2 * pi / 12:2*pi;
x1 = sizein / 2 * cos(sita) + windowcenter(1);
y1 = sizein / 2 * sin(sita) + windowcenter(2);
x2 = (sizein / 2 - majorticklongth) * cos(sita) + windowcenter(1);
y2 = (sizein / 2 - majorticklongth) * sin(sita) + windowcenter(2);
for i = 1:12
    Screen('Drawline', wPtr, majortickcolor, y1(i), x1(i), y2(i), x2(i), majortickwidth);
end
%% 标上数字:标次要数字及主要数字
Screen('TextFont',wPtr, 'Courier New');
Screen('TextSize', wPtr, minornumsize);
% 求应该标上文字的坐标
sita = 0:2*pi/12:2*pi;
% x2, y2为文字的中心点
x2 = (sizein / 2 - majorticklongth - minornumsize / 2) * sin(sita) + windowcenter(1);
y2 = - (sizein / 2 - majorticklongth - minornumsize / 2) * cos(sita) + windowcenter(2);
offsety =  - minornumsize * 0.62;
offsetx = - minornumsize * 0.3;
x2 = x2 + offsetx;
y2 = y2 + offsety;
for i = 1:12
    if (mod(i - 1, 3)~=0)
        Screen('DrawText', wPtr, sprintf('%d', i -1), x2(i), y2(i), minornumcolor);
    end
end
Screen('TextSize', wPtr, majornumsize);
%spaceratio = 1.1;  % 需要为文本预留的空间
Screen('DrawText', wPtr, '12', windowcenter(1) - majornumsize * 0.8 , windowcenter(2) - sizein / 2 + majorticklongth, majornumcolor);
Screen('DrawText', wPtr, '6', windowcenter(1) - majornumsize / 2, windowcenter(2) + sizein / 2 - majorticklongth - majornumsize * 1.3, majornumcolor);
Screen('DrawText', wPtr, '3', windowcenter(1) + sizein / 2 - majorticklongth - majornumsize * 0.9 , windowcenter(2) - majornumsize / 2 * 1.2, majornumcolor);
Screen('DrawText', wPtr, '9', windowcenter(1) - sizein / 2 + majorticklongth , windowcenter(2) - majornumsize / 2 * 1.2, majornumcolor);

%% 画时针 分针 秒针

eclipsed = nowGS - startt;
datenownew = datein + eclipsed / ( 24 * 3600);

% 判断是否需要报时
temp1 = datevec(datenownew);
temp2 = datevec(datenowold);
if temp1(5) ~= temp2(5)
    telltimeflag = 1;
else
    telltimeflag = 0;
end
datenowold = datenownew;
% % 判断注视点是否变色。 
% 
% % 如果需要准备下次变色
% if NeedChange
%     if nowGS > LastActionTime
%         waittime = -1;
%         while (waittime <0)
%             waittime = 5 * randn + 10; % 被试反应后，在下次注视点变色之前等待的时间，其分布服从N(10,5);
%         end
%         waittime = 0.05 + waittime;   % 保证waittime大于0
%         NextChangeTime = LastActionTime + waittime;
%         % 准备好了下次变色
%     end
% end
% % 判断是否需要立即变色
% 
% %


datevector = datevec(datenownew);
% 时针  先不画箭头
hourhandlength = 0.25 * sizein;
hourhandwidth = 0.05 * sizein / penWidthDefault;
hourhandcolor = [0, 255, 255];
angle = pi/2 - (2*pi * (mod(datevector(4),12) / 12) + 2*pi/12 * (mod(datevector(5),60) / 60) +  2*pi/(12*60) * (mod(datevector(5),60) / 60));
angle = - angle;
polarline(wPtr, hourhandcolor, windowcenter, angle, 0, hourhandlength, hourhandwidth, 1); % 所以线宽的单位是什么呢？
% Screen('DrawLine',wPtr, hourhandcolor, ...
%     windowcenter(1) + hourhandlength * cos(angle), ...
%     windowcenter(2) + hourhandlength * sin(angle), ...
%     windowcenter(1), windowcenter(2), hourhandwidth); 
% 可以自己写一个画箭头的函数
minhandlength = 0.40 * sizein;
minhandwidth = 0.03 * sizein / penWidthDefault;
minhandcolor = [255, 0, 0];
angle = pi/2 - (2*pi * (mod(datevector(5),60) / 60) + 2*pi / 60 * (mod(datevector(6),60) / 60));
angle = - angle;
polarline(wPtr, minhandcolor, windowcenter, angle, 0, minhandlength, minhandwidth, 1);
% Screen('DrawLine',wPtr, minhandcolor, ...
%     windowcenter(1) + minhandlength * cos(angle), ...
%     windowcenter(2) + minhandlength * sin(angle), ...
%     windowcenter(1), windowcenter(2), minhandwidth); 
% 秒针
sechandlength = 0.49 * sizein;
sechandwidth = 0.01 * sizein / penWidthDefault;
sechandcolor = [0, 0, 255];
angle = pi/2 - 2*pi * (mod(datevector(6),60) / 60);
angle = - angle;
polarline(wPtr, sechandcolor, windowcenter, angle, 0, sechandlength, sechandwidth, 1); 

%% 时钟下部的文字时间及其他数据
textsize = 20;
Screen('TextSize', wPtr, textsize);
strdate = datestr(datenownew,'mmm dd, yyyy        HH:MM:SS:FFF');
strdate = strdate(1:length(strdate)-2);
textcolor = [0,0,0];
textxoffset = 250;
Screen('DrawText', wPtr, strdate, windowcenter(1) - textxoffset ,windowcenter(1) + 5 + sizein / 2, textcolor); % +5：在钟表和文字间留出距离
text2 = sprintf('Hit: %d, Miss: %d, False alarm: %d.', nhit, nmiss, nfalsea);
Screen('DrawText', wPtr, text2, windowcenter(1) - textxoffset,windowcenter(1) + 5 + 5 + textsize + sizein / 2, textcolor); % +5：在钟表和文字间留出距离
 Screen('DrawText', wPtr, sprintf('%d',fps),0,0,textcolor);
%% 最后：画表盘边缘和中央的注视点
ovalframecolor = [0,0,0];  % 表盘边界颜色
penwidth = 0.01 * sizein; penheight = 0.01 * sizein; % 默认的粗细为1%的表盘直径 
Screen('FrameOval', wPtr, ovalframecolor, ovalrect, penwidth, penheight);
%% 注视点
% 判断是否需要变色
% 每一个nextchangetime对应一个 nextchangedflag  0： 该次改变还未生效 1：该次改变已经生效
% fixdotcolor = fixdotcolor1;   % 中央注视点原始颜色
if waitstatus == 1 % 现在注视点是绿色，需要确定什么时候变回来 
    if nowGS > ChangedToGreenTime + Greendur
        waitstatus = 2;
        fixdotcolor = fixdotcolor1;   % 中央注视点原始颜色        
    else
        fixdotcolor = fixdotcolor2;
    end
elseif waitstatus == 2  % 
    fixdotcolor = fixdotcolor1;
elseif waitstatus == 31
    % 需要产生下一个变到绿色的时间
     waittime = -1;
    while (waittime <3 || waittime > 9)   % 两次变色至少间隔三秒
        waittime = 3 * randn + 6; % 被试反应后，在下次注视点变色之前等待的时间，其分布服从N(6,3); 平均每分钟变色十次，切只取大于3的随机数，故均值为6
    end
    ChangedToGreenTime = nowGS + waittime;
%     disp(waittime);
     fixdotcolor = fixdotcolor1;
     waitstatus = 32;
elseif waitstatus == 32
    % 需要准备变色了
    if nowGS > ChangedToGreenTime
        fixdotcolor = fixdotcolor2;
        waitstatus = 1;
    else
        fixdotcolor = fixdotcolor1;
    end
end

fixdotsize = 0.05 * sizein;  % 中央注视点直径为5%的表盘直径
[fixdotrect, ~, ~] = CenterRect([0, 0, fixdotsize, fixdotsize], windowsize);
Screen('FillOval', wPtr, fixdotcolor, fixdotrect);
Screen('DrawingFinished',wPtr); % 通知PTB画完了
% 显示所画内容
[~,~,FlipTimestampnew,~,~] = Screen('Flip', wPtr);
 fps = 1 / (FlipTimestampnew - FlipTimestampold);
 FlipTimestampold = FlipTimestampnew;
%% 报时
if telltimeflag 
    beepdata = [beep, transpose(hours{round(datevector(4))+1,1}),...
        transpose(minutes{round(datevector(5))+1,1})];
    beepdata = [beepdata;beepdata];
    PsychPortAudio('FillBuffer', pahandle, beepdata);
    PsychPortAudio('Start', pahandle);
end
end %%%%%%%%%%%%%%%%%%%%%%%表盘
%% 收尾工作
Screen('CloseAll');
PsychPortAudio('Stop', pahandle);
rt = mean(rtall);
disp(text2);
textrt = sprintf('Mean RT for all hits (SD): %03d(%03d) ms.', round(rt * 1000), round(std(rtall) * 1000));
disp(textrt);

function polarline(wPtr, color, center, sita, startr, endr, penWidth, varargin)
%　在极坐标背景下画线
% polarline(wPtr, color, center, sita, startr, endr, penWidth [, arrow = 0])
% parameters:
% wPtr 屏幕句柄
% color 颜色[R,G,B]
% center 极坐标的原点在屏幕中的位置
% sita 旋转角，以弧度为单位
% startr, endr, 线段的两端点与原点的距离，单位 像素
% penWidth 画笔宽度
% arrow:  0:无箭头   1： 有箭头
Screen('DrawLine',wPtr, color, center(1) + startr * cos(sita), center(2) + startr * sin(sita),...
    center(1) + endr * cos(sita), center(2) + endr * sin(sita), penWidth);
if nargin == 8
    if varargin{1} ==1
        arrowangle = 20 / 180 * pi;
        arrowlength = abs(startr - endr) * 0.2;
        Screen('DrawLine',wPtr, color, ...
            center(1) + endr * cos(sita), center(2) + endr * sin(sita),...
            center(1) + endr * cos(sita) - arrowlength * cos(arrowangle + sita),...
            center(2) + endr * sin(sita) - arrowlength * sin(arrowangle + sita),...
            penWidth);
        Screen('DrawLine',wPtr, color, ...
            center(1) + endr * cos(sita), center(2) + endr * sin(sita),...
            center(1) + endr * cos(sita) - arrowlength * cos(-arrowangle + sita),...
            center(2) + endr * sin(sita) - arrowlength * sin(-arrowangle + sita),...
            penWidth);
    end
end

%% 是否需要关闭声音？？？？？？？
