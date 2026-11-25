function [MATE_SOC]=MateConvertForFPGA(MATE,opt)

if nargin==1
    opt=0;
end
% format parameter for FPGA simulation

% opt=1: D is 16x16 D(1:10) is RLCsw SWFINV first...
% opt=2: D is 16x16 D(1:8) is RLCsw VariableL first  D(9:16) other source
% with SWFINV first

MAX_INPUTS=16;
MAX_OUTPUTS=16;
MAX_SWITCHES=8;

sourcenames=MATE.sourcenames(:,1);
MATE_SOC.MATE=MATE;

%find switch pairs

Elements=find_system(MATE.model,'MatchFilter', @Simulink.match.activeVariants, 'FollowLinks', 'on','LookUnderMasks','all','MaskType','Pejovic Element for FPGA simulation');
Inverters2L=find_system(MATE.model,'MatchFilter', @Simulink.match.activeVariants, 'FollowLinks', 'on','LookUnderMasks','all','MaskType','MATE Compensated Pejovic 2-level inverter');
Switches=find_system(MATE.model,'MatchFilter', @Simulink.match.activeVariants, 'FollowLinks', 'on','LookUnderMasks','all','MaskType','Pejovic Element for FPGA simulation','typ','Switch');
Inductors=find_system(MATE.model,'MatchFilter', @Simulink.match.activeVariants, 'FollowLinks', 'on','LookUnderMasks','all','MaskType','Pejovic Element for FPGA simulation','typ','Inductor');
Capacitors=find_system(MATE.model,'MatchFilter', @Simulink.match.activeVariants, 'FollowLinks', 'on','LookUnderMasks','all','MaskType','Pejovic Element for FPGA simulation','typ','Capacitor');
InductorsRL=find_system(MATE.model,'MatchFilter', @Simulink.match.activeVariants, 'FollowLinks', 'on','LookUnderMasks','all','MaskType','Discrete variable High Accuracy Series RL or Parallel RC branch','typ','Series RL');
CapacitorsRC=find_system(MATE.model,'MatchFilter', @Simulink.match.activeVariants, 'FollowLinks', 'on','LookUnderMasks','all','MaskType','Discrete variable High Accuracy Series RL or Parallel RC branch','typ','Parallel RC');
SWF_2Linverters=find_system(MATE.model,'MatchFilter', @Simulink.match.activeVariants, 'FollowLinks', 'on','LookUnderMasks','all','MaskType','MATE Inverter Switching Function (2-level IGBT/Diode) (3-phase)');
SWF_2Linverters1PH=find_system(MATE.model,'MatchFilter', @Simulink.match.activeVariants, 'FollowLinks', 'on','LookUnderMasks','all','MaskType','MATE Inverter Switching Function (2-level IGBT/Diode) (1-phase)');
PMSMs=find_system(MATE.model,'MatchFilter', @Simulink.match.activeVariants, 'FollowLinks', 'on','LookUnderMasks','all','MaskType','MATE Permanent Magnet Synchronous Machine');

order=[];
ordertype=[];
if opt==1 || opt==0

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 2-level switching function inverter %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:size(SWF_2Linverters,1)
    
    isen=[SWF_2Linverters{i}  '/Isensor1'];   % 3 of this Isensor1 2 3
    vsen=[SWF_2Linverters{i} '/Vdc'];    % 1 of this
    vsrc=[SWF_2Linverters{i}  '/CVS1'];       % 3 of this VCS1 2 3
    isrc=[SWF_2Linverters{i}  '/CCS_Idc'];    % one of this
    flag=0;
    for j=1:size(MATE.sourcenames,1)
        if isequal(vsrc,MATE.sourcenames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:30 v')
    end
    order=[order j j+1 j+2];
    ordertype=[ordertype 2 2 2];
    disp(['re-order of Switching function inverter Vac source A: ' SWF_2Linverters{i}])
    disp(['re-order of Switching function inverter Vac source B: ' SWF_2Linverters{i}])
    disp(['re-order of Switching function inverter Vac source C: ' SWF_2Linverters{i}])
    flag=0;
    for j=1:size(MATE.sourcenames,1)
        if isequal(isrc,MATE.sourcenames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:30 i')
    end
    order=[order j];
    ordertype=[ordertype 2];
    disp(['re-order of Switching function inverter Idc source: ' SWF_2Linverters{i}])
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% PMSM                                %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:size(PMSMs,1)
    
    vsen=[PMSMs{i}  '/Mutual with losses/VM1'];   % 3 of this VM1 2 3
    isrc=[PMSMs{i}  '/Mutual with losses/CCS1'];       % 3 of this CCS1 2 3

    flag=0;
    for j=1:size(MATE.sourcenames,1)
        if isequal(isrc,MATE.sourcenames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:40 v')
    end
    order=[order j j+1 j+2];
    ordertype=[ordertype 3 3 3];
    disp(['re-order of PMSM source A: ' isrc])
    disp(['re-order of PMSM source B: ' isrc])
    disp(['re-order of PMSM source C: ' isrc])

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 2-level Pejovic inverter            %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for i=1:size(Inverters2L,1)
    upp=[Inverters2L{i} '/upper/CCS1'];
    loo=[Inverters2L{i} '/lower/CCS1'];
    orr=[];
    orrs=[0 0];
    for j=1:size(MATE.sourcenames,1)
        %MATE.sourcenames{j,1}
        if isequal(upp,MATE.sourcenames{j,1})
            orr(1)=j;
            orrs(1)=1;
        end
        if isequal(loo,MATE.sourcenames{j,1})
            orr(2)=j;
            orrs(2)=1;
        end
        if sum(orrs)==2
            break;
        end
    end
    if sum(orrs)<2
        error('MateConvertForFPGA:1')
    end
    order=[order orr];
    ordertype=[ordertype 1 1];
    disp(['re-order of Power compensated inverter: ' Inverters2L{i}])
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Pejo switch                         %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:size(Switches,1)
    upp=[Switches{i} '/CCS1'];
    flag=0;
    for j=1:size(MATE.sourcenames,1)
        if isequal(upp,MATE.sourcenames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:4')
    end
    order=[order j];
    ordertype=[ordertype 1];
    disp(['re-order of switch: ' upp])
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Inductors                           %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:size(Inductors,1)
    upp=[Inductors{i} '/CCS1'];
    flag=0;
    for j=1:size(MATE.sourcenames,1)
        if isequal(upp,MATE.sourcenames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:2')
    end
    order=[order j];
    ordertype=[ordertype 1];
    disp(['re-order of Inductor: ' upp])

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Capacitors                          %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:size(Capacitors,1)
    upp=[Capacitors{i} '/CCS1'];
    flag=0;
    for j=1:size(MATE.sourcenames,1)
        if isequal(upp,MATE.sourcenames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:3')
    end
    order=[order j];
    ordertype=[ordertype 1];
    disp(['re-order of capacitor: ' upp])

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Other inputs                        %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% find the rest of source and put it at the end of the inputs.
notPejoInputs=[];
for i=1:size(MATE.source,1)
    if ~any(order==i, "all")
        notPejoInputs=[notPejoInputs i];
        disp(['re-order of ' MATE.sourcenames{i,1} ' to index ' num2str(length(notPejoInputs))])
    end
end



outorder=[];

for i=1:size(SWF_2Linverters,1)
    isen=[SWF_2Linverters{i}  '/Isensor1'];   % 3 of this Isensor1 2 3
    vsen=[SWF_2Linverters{i} '/Vdc'];    % 1 of this
    vsrc=[SWF_2Linverters{i}  '/CVS1'];       % 3 of this VCS1 2 3
    isrc=[SWF_2Linverters{i}  '/CCS_Idc'];    % one of this

    flag=0;
    for j=1:size(MATE.allSensorNames,1)
        if isequal(isen,MATE.allSensorNames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:31 vsensor')
    end
    outorder=[outorder j j+1 j+2];
    disp(['re-order of inverter Iout sensor (phase A): ' MATE.allSensorNames{j,1}])
    disp(['re-order of inverter Iout sensor (phase B): ' MATE.allSensorNames{j,1}])
    disp(['re-order of inverter Iout sensor (phase C): ' MATE.allSensorNames{j,1}])
    flag=0;
    for j=1:size(MATE.allSensorNames,1)
        if isequal(vsen,MATE.allSensorNames{j,1})
            flag=1;
            break;
        end
    end
    if flag==0
        error('MateConvertForFPGA:31 isensor')
    end
    outorder=[outorder j];
    disp(['re-order of inverter Vdc sensor: ' MATE.allSensorNames{j,1}])

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% PMSM                    %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:size(PMSMs,1)
    vsen=[PMSMs{i}  '/Mutual with losses/VM1'];   % 3 of this VM1 2 3
    isrc=[PMSMs{i}  '/Mutual with losses/CCS1'];       % 3 of this CCS1 2 3

    flag=0;
    for j=1:size(MATE.allSensorNames,1)
        if isequal(vsen,MATE.allSensorNames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:41 vsensor')
    end
    outorder=[outorder j j+1 j+2];
    disp(['re-order of PMSM Vsensor (phase A): ' vsen])
    disp(['re-order of PMSM Vsensor (phase B): ' vsen])
    disp(['re-order of PMSM Vsensor (phase C): ' vsen])


end

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:length(order)
    weHaveMatch=0;
    if ordertype(i)==1
        nodes=MATE.source(order(i),1:2);
        % find the index in yout
        for j=1:size(MATE.yout,1)
            isU_n=strfind(MATE.yout(j,:),'U_n');
            if ~isempty(isU_n)
                loc=strfind(MATE.yout(j,:),'_');
                outnodes=[ str2num(MATE.yout(j,loc(1)+2:loc(2)-1)) str2num(MATE.yout(j,loc(2)+1:end))];  
            end
            if length(outnodes)==2
                if nodes(1)==outnodes(1)  && nodes(2)==outnodes(2)
                    weHaveMatch=1;
                    outorder=[outorder j];
                    break;
                end
            end
        end
        if weHaveMatch==0
            error('MateConvertForFPGA:5')
        end
    end
end

% find the rest of yout and put it at the end of the outputs
notPejoOutputs=[];
for i=1:size(MATE.yout,1)
    if ~any(outorder==i, "all")
        notPejoOutputs=[notPejoOutputs i];
    end
end

% permute Inputs of D

nbPejo=length(order);
nb_notPejoIn=length(notPejoInputs);
nb_notPejoOut=length(notPejoOutputs);
order=[order notPejoInputs];
outorder=[outorder notPejoOutputs];
DD=MATE.Ddp{1}(outorder,order);
MATE_SOC.new_sourcenames=sourcenames(order);
MATE_SOC.new_outputnames=MATE.allSensorNames(outorder);
[a,b]=size(DD);
DD=[DD zeros(a,MAX_INPUTS-b)];
DD=[DD; zeros(MAX_INPUTS-a, MAX_INPUTS)];
MATE_SOC.D=DD;
MATE_SOC.orderin=order;
MATE_SOC.orderout=outorder;

if opt==1

    newDD=zeros(16,16);
    % newDD(1:nbPejo,1:nbPejo)=DD(1:nbPejo,1:nbPejo);
    % newDD(11:11+nb_notPejoOut-1,:)=DD(nbPejo+1:nbPejo+nb_notPejoOut,:);
    % newDD(:,11:11+nb_notPejoIn-1,:)=DD(:,nbPejo+1:nbPejo+nb_notPejoIn);
    newDD([1:nbPejo 11:11+nb_notPejoOut-1],[1:nbPejo 11:11+nb_notPejoIn-1])=DD(1:nbPejo+nb_notPejoOut,1:nbPejo+nb_notPejoIn);
    MATE_SOC.Dpack=DD;
    MATE_SOC.D=newDD; 

end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%555
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%% NEW %%%%%%%%
%%%%%%%%%%%5 METHOD %%%%%%%%%%%%%55

if opt==2

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% INPUTS %%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('Reordering inputs')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Inductors                           %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:size(InductorsRL,1)
    upp=[InductorsRL{i} '/CCS1'];
    flag=0;
    for j=1:size(MATE.sourcenames,1)
        if isequal(upp,MATE.sourcenames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:2')
    end
    order=[order j];
    ordertype=[ordertype 1];
    %disp(['re-order of Inductor: ' upp])
    disp(['new input: '  num2str(length(order)) ' inductor: '  InductorsRL{i}])

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Capacitors                          %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:size(CapacitorsRC,1)
    upp=[CapacitorsRC{i} '/CCS1'];
    flag=0;
    for j=1:size(MATE.sourcenames,1)
        if isequal(upp,MATE.sourcenames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:3')
    end
    order=[order j];
    ordertype=[ordertype 1];
    %disp(['re-order of capacitor: ' upp])
    disp(['new input: '  num2str(length(order)) ' capacitor: '  CapacitorsRC{i}])

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 2-level Pejovic inverter            %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for i=1:size(Inverters2L,1)
    upp=[Inverters2L{i} '/upper/CCS1'];
    loo=[Inverters2L{i} '/lower/CCS1'];
    orr=[];
    orrs=[0 0];
    for j=1:size(MATE.sourcenames,1)
        if isequal(upp,MATE.sourcenames{j,1})
            orr(1)=j;
            orrs(1)=1;
        end
        if isequal(loo,MATE.sourcenames{j,1})
            orr(2)=j;
            orrs(2)=1;
        end
        if sum(orrs)==2
            break;
        end
    end
    if sum(orrs)<2
        error('MateConvertForFPGA:1')
    end
    order=[order orr];
    ordertype=[ordertype 1 1];
    disp(['new input: ' num2str(length(order)-1) ':' num2str(length(order)) ' Power compensated inverter'  Inverters2L{i}])
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Pejo switch                         %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:size(Switches,1)
    upp=[Switches{i} '/CCS1'];
    flag=0;
    for j=1:size(MATE.sourcenames,1)
        if isequal(upp,MATE.sourcenames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:4')
    end
    order=[order j];
    ordertype=[ordertype 1];
    %disp(['re-order of switch: ' upp])
    disp(['new input: '  num2str(length(order)) ' pejo switch: '  Switches{i}])
end

%%% outorder of RL_pejoSW
outorder=[];
outorder=find_output(MATE,order,ordertype,outorder);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 2-level switching function inverter %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('SWF inverter re-order (offset 8)')
for i=1:size(SWF_2Linverters1PH,1)
    
    isen=[SWF_2Linverters1PH{i}  '/Isensor'];   % 1 of this Isensor1 2 3
    vsen=[SWF_2Linverters1PH{i} '/Vdc'];    % 1 of this
    vsrc=[SWF_2Linverters1PH{i}  '/CVS'];       % 1 of this VCS1 2 3
    isrc=[SWF_2Linverters1PH{i}  '/CCS_Idc'];    % one of this
    flag=0;
    for j=1:size(MATE.sourcenames,1)
        if isequal(vsrc,MATE.sourcenames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:30 v')
    end
    order=[order j ];
    ordertype=[ordertype 2 ];
    %disp(['re-order of Switching function inverter Vac phase A: ' SWF_2Linverters1PH{i}])
    disp(['new input: '  num2str(length(order)) ' SW inverter: Vac source'  SWF_2Linverters1PH{i}])

    flag=0;
    for j=1:size(MATE.sourcenames,1)
        if isequal(isrc,MATE.sourcenames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:30 i')
    end
    order=[order j];
    ordertype=[ordertype 2];
    %disp(['re-order of Switching function inverter Idc source: ' SWF_2Linverters1PH{i}])
    disp(['new input: '  num2str(length(order)) ' SW inverter: Idc source'  SWF_2Linverters1PH{i}])
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% PMSM                                %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:size(PMSMs,1)
    
    vsen=[PMSMs{i}  '/Mutual with losses/VM1'];   % 3 of this VM1 2 3
    isrc=[PMSMs{i}  '/Mutual with losses/CCS1'];       % 3 of this CCS1 2 3

    flag=0;
    for j=1:size(MATE.sourcenames,1)
        if isequal(isrc,MATE.sourcenames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:40 v')
    end
    order=[order j j+1 j+2];
    ordertype=[ordertype 3 3 3];
    disp(['re-order of PMSM source A: ' isrc])
    disp(['re-order of PMSM source B: ' isrc])
    disp(['re-order of PMSM source C: ' isrc])

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Other inputs                        %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% find the rest of source and put it at the end of the inputs.
disp('Ordering other inputs (offset=8) in D matrix')
otherInputs=[];
for i=1:size(MATE.source,1)
    if ~any(order==i, "all")
        otherInputs=[otherInputs i];
        disp([ 'New index ' num2str(length(otherInputs)) ' Other sources name: ' MATE.sourcenames{i,1} ]);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% OUTPUTS %%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


disp('Other output (non RLC_pejosw) reorder:')

for i=1:size(SWF_2Linverters1PH,1)
    isen=[SWF_2Linverters1PH{i}  '/Isensor'];   % 1 of this Isensor1
    vsen=[SWF_2Linverters1PH{i} '/Vsensor'];    % 1 of this
    vsrc=[SWF_2Linverters1PH{i}  '/CVS'];       % 1 of this VCS1
    isrc=[SWF_2Linverters1PH{i}  '/CCS_Idc'];    % one of this

    flag=0;
    for j=1:size(MATE.allSensorNames,1)
        if isequal(isen,MATE.allSensorNames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:31 vsensor')
    end
    outorder=[outorder j ];
    %disp(['re-order of inverter Iout sensor (phase A): ' MATE.allSensorNames{j,1}])
    disp(['new output: ' num2str(length(outorder)) 'signal: ' MATE.allSensorNames{j,1}])

    flag=0;
    for j=1:size(MATE.allSensorNames,1)
        if isequal(vsen,MATE.allSensorNames{j,1})
            flag=1;
            break;
        end
    end
    if flag==0
        error('MateConvertForFPGA:31 isensor')
    end
    outorder=[outorder j];
    %disp(['re-order of inverter Vdc sensor: ' MATE.allSensorNames{j,1}])
    disp(['new output: ' num2str(length(outorder)) 'signal: ' MATE.allSensorNames{j,1}])

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% PMSM                    %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:size(PMSMs,1)
    vsen=[PMSMs{i}  '/Mutual with losses/VM1'];   % 3 of this VM1 2 3
    isrc=[PMSMs{i}  '/Mutual with losses/CCS1'];       % 3 of this CCS1 2 3

    flag=0;
    for j=1:size(MATE.allSensorNames,1)
        if isequal(vsen,MATE.allSensorNames{j,1})
            flag=1;
            break;
        end

    end
    if flag==0
        error('MateConvertForFPGA:41 vsensor')
    end
    outorder=[outorder j j+1 j+2];
    disp(['re-order of PMSM Vsensor (phase A): ' vsen])
    disp(['re-order of PMSM Vsensor (phase B): ' vsen])
    disp(['re-order of PMSM Vsensor (phase C): ' vsen])


end



% find the rest of yout and put it at the end of the outputs
disp('Ordering other outputs (offset=8) in D matrix')
otherOutputs=[];
for i=1:size(MATE.yout,1)
    if ~any(outorder==i, "all")
        otherOutputs=[otherOutputs i];
        disp([ 'New index ' num2str(num2str(length(otherOutputs))) ' Other sources name: ' MATE.allSensorNames{i,1} ]);
    end
end

% permute Inputs of D

% nbPejo=length(order);
% nb_notPejoIn=length(notPejoInputs);
% nb_notPejoOut=length(notPejoOutputs);
% order=[order notPejoInputs];
% outorder=[outorder notPejoOutputs];
% DD=MATE.Ddp{1}(outorder,order);

nbPejo=sum(ordertype==1);
nb_inv=sum(ordertype==2);
nb_pmsm=sum(ordertype==3);
nb_otherIN=length(otherInputs)+nb_inv;
nb_otherOUT=length(otherOutputs)+nb_inv; % we put SWFINV inot the 'other' in/out
order=[order otherInputs];
outorder=[outorder otherOutputs];
DD=MATE.Ddp{1}(outorder,order);
MATE_SOC.new_sourcenames=sourcenames(order);
MATE_SOC.new_outputnames=MATE.allSensorNames(outorder);
[a,b]=size(DD);
DD=[DD zeros(a,MAX_INPUTS-b)];
DD=[DD; zeros(MAX_OUTPUTS-a, MAX_INPUTS)];
MATE_SOC.D=DD;
MATE_SOC.orderin=order;
MATE_SOC.orderout=outorder;


    disp('RLCsw item located in row/col 1:8 of D')
    newDD=zeros(16,16);
    % newDD(1:nbPejo,1:nbPejo)=DD(1:nbPejo,1:nbPejo);
    % newDD(11:11+nb_notPejoOut-1,:)=DD(nbPejo+1:nbPejo+nb_notPejoOut,:);
    % newDD(:,11:11+nb_notPejoIn-1,:)=DD(:,nbPejo+1:nbPejo+nb_notPejoIn);
    newDD([1:nbPejo 11-2:11-2+nb_otherOUT-1],[1:nbPejo 11-2:11-2+nb_otherIN-1])=DD(1:nbPejo+nb_otherOUT,1:nbPejo+nb_otherIN);
    MATE_SOC.Dpack=DD;
    MATE_SOC.D=newDD; 



end

disp('MATE-SoCS data generated with success')
end

function outorder=find_output(MATE,order,ordertype,outorder)
%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:length(order)
    weHaveMatch=0;
    if ordertype(i)==1
        nodes=MATE.source(order(i),1:2);
        % find the index in yout
        for j=1:size(MATE.yout,1)
            isU_n=strfind(MATE.yout(j,:),'U_n');
            if ~isempty(isU_n)
                loc=strfind(MATE.yout(j,:),'_');
                outnodes=[ str2num(MATE.yout(j,loc(1)+2:loc(2)-1)) str2num(MATE.yout(j,loc(2)+1:end))];  
            end
            if length(outnodes)==2
                if nodes(1)==outnodes(1)  && nodes(2)==outnodes(2)
                    weHaveMatch=1;
                    outorder=[outorder j];
                    break;
                end
            end
        end
        if weHaveMatch==0
            error('MateConvertForFPGA:5')
        end
    end
end
end







