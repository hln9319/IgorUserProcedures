// See http://www.igorexchange.com/project/matrixFileReader for installation steps.
// Copy "MatrixFileReader.ipf" and "ImagePuzzle.ipf" to
// "My Documents\WaveMetrics\Igor Pro 6 User Files\User Procedures"

#include <image line profile>
#include "colorController"
#include "ImagePuzzle"
#include "MatrixFileReader"

menu "AFM"
	"Data Analyzer", start()
	"Color Controller", colorControl()
end

// loadingInfo[][0]: file path, loadingInfo[][1]: sample name, loadingInfo[][2]: total folders
Function initialize()
	variable/G brickletID = 1, startBrickletID = 1, endBrickletID = 1, numBricklets = 0
	string/G resultFileName,resultFilePath,lastResultFileName,lastResultFilePath
	variable/G V_MatrixFileReaderDouble=0, V_MatrixFileReaderDebug=0, V_MatrixFileReaderFolder=1, V_MatrixFileReaderOverwrite=1, V_MatrixFileReaderCache=1

	String/g scanMove
	Variable/g loadingNum = -1, totalLoads = 0, folderNumber=1, runCycleCount = 1
	Variable/g scanCycleCount = 1, channel, allXOffset, allLength = 500, allYOffset, allHeight = 500
	Variable/g xOffset, length, yOffset, height, x0InPuzzle, y0InPuzzle
	make/T fullInfo, folderInfo
	make/T/N=(10, 3) loadingInfo
	make/N=(15, 13) puzzleParts
End

Macro start()
	if (WinType("AFMdataAnalyzer") != 7)
		AFMdataAnalyzer()
		initialize()
	endif
	myPanel()
	KillWindow MatrixFileReader
EndMacro

Window AFMdataAnalyzer() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(1351,204,1538,432) as "AFMdataAnalyzer"
	SetDrawLayer UserBack
	Button openFile,pos={10,10},size={50,20},proc=Load,title="Load"
	Button showgraph,pos={10,45},size={50,20},proc=ButtonProc,title="Show"
	SetVariable folderNumber,pos={70,45},size={80,16},proc=folderNumberChanged,title="Folder"
	SetVariable folderNumber,help={"A folder has four images, up, down, re_up, and re_down."}
	SetVariable folderNumber,limits={1,inf,1},value= folderNumber
	Button button0,pos={100,195},size={80,20},proc=checkInfo,title="Information"
	Button button1,pos={10,135},size={80,20},proc=LineProfile,title="LineProfile"
	Button button1,help={"Cursors should be placed first"}
	Button button3,pos={10,195},size={80,20},proc=OffsetPlane,title="OffsetPlane"
	Button SaveImage,pos={100,135},size={80,20},proc=SaveImage,title="Copy Image"
	Button addScaleBar,pos={100,165},size={80,20},proc=AddScaleBar,title="Scale Bar"
	SetVariable loadingNum,pos={60,10},size={30,16},title=" "
	SetVariable loadingNum,limits={-1,inf,1},value= loadingNum
	Button remove,pos={100,10},size={80,20},proc=removeLoad,title="Remove"
	SetVariable runCycleCount,pos={10,75},size={80,16},proc=scanIdChanged,title=" scan ID"
	SetVariable runCycleCount,limits={1,inf,1},value= runCycleCount
	SetVariable scanCycleCount,pos={90,75},size={30,16},proc=scanIdChanged,title=" "
	SetVariable scanCycleCount,limits={1,inf,1},value= scanCycleCount
	Button buildPuzzle,pos={10,165},size={80,20},proc=buildPuzzle,title="Build Puzzle"
	PopupMenu channelNameMenu,pos={10,95},size={142,28},proc=channelNameMenuSelected,title="Channel"
	PopupMenu channelNameMenu,mode=1,popvalue="Damping",value= #"\"Damping;Df;Z;Fn;Fl\""
EndMacro

static StrConstant resultFileSuffix = ".mtrx"
static StrConstant preferencesFolder = "root:Packages:MatrixFileReader:BasicGUI"

static Function initStruct(errorCode)
	Struct errorCode &errorCode

	errorCode.SUCCESS =0
	errorCode.UNKNOWN_ERROR=10001
	errorCode.ALREADY_FILE_OPEN=10002
	errorCode.EMPTY_RESULTFILE=10004
	errorCode.FILE_NOT_READABLE=10008
	errorCode.NO_NEW_BRICKLETS=10016
	errorCode.WRONG_PARAMETER=10032
	errorCode.INTERNAL_ERROR_CONVERTING_DATA=10064
	errorCode.NO_FILE_OPEN=10128
	errorCode.INVALID_RANGE=10256  
	errorCode.WAVE_EXIST=10512
end

static Function/DF createDFWithAllParents(dataFolder)
	string dataFolder

	variable i
	string partialPath="root"
	for(i=1; i < ItemsInList(dataFolder,":"); i+=1) // skip root, as this exists always
		partialPath += ":"
		partialPath += StringFromList(i,dataFolder,":")
		if(!DataFolderExists(partialPath))
			NewDataFolder/O $partialPath
		endif
	endfor
	
	return $dataFolder
end

Function openAllFiles()
	Struct errorCode errorCode
	initStruct(errorCode)
	DFREF saveDFR = GetDataFolderDFR()
	createDFWithAllParents(preferencesFolder)
			
	SetDataFolder preferencesFolder

	NVAR brickletID, startBrickletID, endBrickletID, numBricklets
	SVAR resultFileName, resultFilePath, lastResultFileName, lastResultFilePath

	SetDataFolder saveDFR
	
	// Open file
	variable refNum

	MFR_OpenResultFile
	if( V_flag == errorCode.SUCCESS )
		updatePanel()
		lastResultFileName = resultFileName
		lastResultFilePath = resultFilePath
	else
		MFR_GetXOPErrorMessage
	endif
	
	if (isFilesAlreadyLoaded(resultFilePath, resultFileName, num2str(numBricklets)) != 0)
		// Get all data
		MFR_GetBrickletData
		if(V_flag != errorCode.SUCCESS)
			MFR_GetXOPErrorMessage
		endif
		MFR_GetBrickletMetaData
		if(V_flag != errorCode.SUCCESS)
			MFR_GetXOPErrorMessage
		endif
		
		newFilesLoaded(resultFilePath, resultFileName, num2str(numBricklets))
		printf "%d file folders has been loaded!\r", numBricklets
	endif
	
	// Close file
	MFR_CloseResultFile
	if( V_flag == errorCode.SUCCESS )
		lastResultFileName = resultFileName
		lastResultFilePath = resultFilePath
	else
		MFR_GetXOPErrorMessage
	endif
	resultFileName = ""
	resultFilePath = ""
	numBricklets=0
End

Function isFilesAlreadyLoaded(path, name, numFiles)
	String path, name, numFiles
	
	Wave/T loadingInfo
	Variable i
	if (WaveExists(loadingInfo))
		for (i = 0; i < DimSize(loadingInfo, 0); i += 1)
			if (cmpstr(loadingInfo[i][0], path) == 0 && cmpstr(loadingInfo[i][1], name) == 0 && cmpstr(loadingInfo[i][2], numFiles) == 0)
				printf "Data already loaded - loadingNum: %d\r", i
				return 0
			endif			
		endfor		
	endif
	return -1;
End

// MatrixFileReader is loading files to folders like :X0001:, and the next load will 
// overwrite the previous one. Here, we copy those folders to :fileSetN:, where N is
// a number. Each load has a different N. Also, this function updates wave "loadingInfo".
Function newFilesLoaded(path, name, numFiles)
	String path, name, numFiles

	NVAR loadingNum, totalLoads, numBricklets
	SVAR resultFileName, resultFilePath
	
	Variable i
	Wave/T loadingInfo

	for (i = 0; i < DimSize(loadingInfo, 0); i += 1) // Check if files has been loaded before.
		if (cmpstr(loadingInfo[i][0], path) == 0 && cmpstr(loadingInfo[i][1], name) == 0)
			loadingNum = i
			copyData(str2num(loadingInfo[i][2]) + 1, str2num(numFiles))
			deleteSourceData(1, str2num(numFiles))
			return 0
		endif			
	endfor
	for (i = 0; i < DimSize(loadingInfo, 0); i += 1)
		if (cmpstr(loadingInfo[i][0], "") == 0)
			loadingNum = i
			break
		endif
		if (i == DimSize(loadingInfo, 0) - 1)
			loadingNum = i + 1
			Redimension/N=(DimSize(loadingInfo, 0) + 10, -1) loadingInfo
			break
		endif
	endfor

	totalLoads += 1
	loadingInfo[loadingNum][0] = path
	loadingInfo[loadingNum][1] = name
	loadingInfo[loadingNum][2] = numFiles
	copyData(1, str2num(numFiles))
	deleteSourceData(1, str2num(numFiles))
End

// i.e. copy waves from X_0001 to X_0013 to fileSet0_0001 - fileSet0_00013
Function copyData(from, to)
	Variable from, to
	
	NVAR loadingNum
	Variable i, j
	string source, destination, hashMap = "folderHash" + num2str(loadingNum)
	for(i = from; i <= to; i += 1)
		sprintf destination, ":fileSet%d_%.5d", loadingNum, i
		newdatafolder/o $destination
		for(j = 1; j <=4; j += 1)
			sprintf source, ":X_%.5d:data_%.5d_"+scanMoveEnum(j), i, i
			sprintf destination, ":fileSet%d_%.5d:data_%.5d_"+scanMoveEnum(j), loadingNum, i, i
			duplicate/o $source $destination
		endfor
		sprintf source, ":X_%.5d:metaData_%.5d", i, i
		sprintf destination, ":fileSet%d_%.5d:metaData_%.5d", loadingNum, i, i
		duplicate/o $source $destination
		if (!WaveExists($hashMap))
			make/N=(64, 8, 5) $hashMap
		endif
		buildFolderHash($destination, $hashMap)
	endfor
End

// i.e. map scan 5-1 Damping mode to its folder number
Function buildFolderHash(info, hashMap)
	Wave/T info
	Wave hashMap
	
	NVAR loadingNum
	Variable row, column, layer, value
	
	row = str2num(info[SearchString(info,"runCycleCount")][1])
	column = str2num(info[SearchString(info,"scanCycleCount")][1])
	value = str2num(info[SearchString(info,"brickletID")][1])
	layer = channelNameToInt(info[SearchString(info,"channelName")][1])
	if (row >= DimSize(hashMap, 0))
		Redimension/N=(row * 2, -1, -1) hashMap
	endif
	if (column >= DimSize(hashMap, 1))
		Redimension/N=(-1, column * 2, -1) hashMap
	endif
	hashMap[row][column][layer] = value
End

Function updateFolderNumber(hashMap)
	Wave hashMap

	NVAR runCycleCount, scanCycleCount, channel, folderNumber
	if (WaveExists(hashMap) && hashMap[runCycleCount][scanCycleCount][channel] > 0)
		folderNumber = hashMap[runCycleCount][scanCycleCount][channel]
		updateImage()
	else
		printf "Folder %d - %d, " +  channelNameIntToString(channel) +" channel does not exist! Plz check loading number and scan ids.\r", runCycleCount, scanCycleCount
	endif
	
	
End

Function/S channelNameIntToString(int)
	Variable int
	
	if (int == 2)
		return "Z"
	elseif (int == 1)
		return "Df"
	elseif (int == 0)
		return "Damping"
	elseif (int == 3)
		return "Fn"
	elseif (int == 4)
		return "Fl"
	else
		return ""
	endif
End

Function channelNameToInt(channelName)
	String channelName
	
	if (cmpstr(channelName, "Z") == 0)
		return 2
	elseif (cmpstr(channelName, "Df") == 0)
		return 1
	elseif (cmpstr(channelName, "Damping") == 0)
		return 0
	elseif (cmpstr(channelName, "Fn") == 0)
		return 3
	elseif (cmpstr(channelName, "Fl") == 0)
		return 4
	else
		return -1
	endif
End

// delete waves like X_00001:xxx
Function deleteSourceData(from, to)
	Variable from, to
	
	Variable i
	String dataFolder
	for(i = from; i <= to; i += 1)
	sprintf dataFolder, ":X_%.5d", i
	KillDataFolder $dataFolder
	endfor
End

Function ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	wave akw2d_Up, akw2d_ReUp, akw2d_Down, akw2d_ReDown
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			updateImage()			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			updateImage()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function updateImage()
	NVAR folderNumber, loadingNum
	string imageFile, tempWaveName, tempWindowName
	variable zRange, n
	string rangeLabel
	wave akw2d_Up, akw2d_ReUp, akw2d_Down, akw2d_ReDown
	wave/T folderInfo, loadingInfo
	if (folderNumber < 1)
		folderNumber = 1
	elseif (folderNumber > str2num(loadingInfo[loadingNum][2]))
		folderNumber = str2num(loadingInfo[loadingNum][2])
		printf "The total number of folders is %d, cannot exceed it.\r", folderNumber
	endif
	UpdateInfo()
	for(n=1;n<=4;n+=1)
		sprintf imageFile, ":fileSet%d_%.5d:data_%.5d_"+scanMoveEnum(n), loadingNum, folderNumber, folderNumber
		sprintf tempWaveName, "akw2d_"+scanMoveEnum(n)
		sprintf tempWindowName, "Image_"+scanMoveEnum(n)
		duplicate/o $imageFile $tempWaveName
		DoWindow/f $tempWindowName
		If(V_flag == 0)
			Display
			dowindow/c $tempWindowName
			AllowSelectionInTopGraph()
		endif
		checkDisplayed $tempWaveName
		if (V_flag == 0)
			AppendImage $tempWaveName;DelayUpdate
			ModifyImage $tempWaveName ctab= {*,*,Terrain,0}
		endif
		zRange = WaveMax($tempWaveName)-WaveMin($tempWaveName)
		sprintf rangeLabel, "Z Range: %.3g " + folderInfo[6], zRange
		TextBox/C/N=text0/F=0/S=3/B=1/A=LT/X=0.00/Y=0.00 rangeLabel
	endfor
	MoveWindow /W=Image_Up 5,10,255,220
	MoveWindow /W=Image_ReUp 265,10,515,220
	MoveWindow /W=Image_Down 5,280,255,500
	MoveWindow /W=Image_ReDown 265,280,515,500
End


Window FileInfo() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(1254,428,1690,662) as "FileInfo"
	SetVariable FilePath,pos={20,20},size={400,16},disable=2,title="FilePath"
	SetVariable FilePath,value= folderInfo[0]
	SetVariable FileName,pos={20,45},size={400,16},disable=2,title="FileName"
	SetVariable FileName,limits={-inf,inf,0},value= folderInfo[1]
	SetVariable setvar2,pos={20,70},size={150,16},disable=2,title="TotalFolderNumbers"
	SetVariable setvar2,limits={-inf,inf,0},value= folderInfo[2]
	SetVariable setvar3,pos={220,70},size={150,16},disable=2,title="Sample"
	SetVariable setvar3,value= folderInfo[3]
	SetVariable setvar4,pos={20,95},size={100,16},disable=2,title="DataSet"
	SetVariable setvar4,limits={-inf,inf,0},value= folderInfo[4]
	SetVariable setvar5,pos={20,120},size={150,16},disable=2,title="ChannelGroup"
	SetVariable setvar5,limits={-inf,inf,0},value= folderInfo[5]
	SetVariable setvar6,pos={20,145},size={180,16},disable=2,title="NonContactAdjustFrequency"
	SetVariable setvar6,limits={-inf,inf,0},value= folderInfo[7]
	SetVariable setvar7,pos={220,145},size={180,16},disable=2,title="NonContactVibrationAmplitude"
	SetVariable setvar7,limits={-inf,inf,0},value= folderInfo[8]
	SetVariable setvar8,pos={20,170},size={400,16},disable=2,title="ScanRange"
	SetVariable setvar8,limits={-inf,inf,0},value= folderInfo[9]
	SetVariable setvar9,pos={220,95},size={174,16},disable=2,title="NumberOfPoints"
	SetVariable setvar9,limits={-inf,inf,0},value= folderInfo[10]
	SetVariable setvar10,pos={220,120},size={100,16},disable=2,title="ChannelUnit"
	SetVariable setvar10,limits={-inf,inf,0},value= folderInfo[6]
	SetVariable xIncrement,pos={20,195},size={190,16},disable=2,title="X Increment"
	SetVariable xIncrement,limits={-inf,inf,0},value= folderInfo[11]
	SetVariable yIncrement,pos={220,195},size={190,16},disable=2,title="Y Increment"
	SetVariable yIncrement,limits={-inf,inf,0},value= folderInfo[12]
EndMacro

Function UpdateInfo()
	NVAR folderNumber, loadingNum, numBricklets
	string infoFile
	wave/T fullInfo, loadingInfo, folderInfo
	variable n
	sprintf infoFile, ":fileSet%d_%.5d:metaData_%.5d", loadingNum, folderNumber, folderNumber
	duplicate/O/T $infoFile fullInfo
	
	folderInfo[0] = loadingInfo[loadingNum][0] // file path
	folderInfo[1] = loadingInfo[loadingNum][1] // file name
	folderInfo[2] = loadingInfo[loadingNum][2] // total folder number
	folderInfo[3] = fullInfo[5][1] // sample name
	folderInfo[4] = fullInfo[6][1] // Data set
	folderInfo[5] = fullInfo[9][1] // Channel group
	folderInfo[6] = fullInfo[24][1] // channel unit
	folderInfo[7] = fullInfo[30][1]+fullInfo[31][1] // noncontact adjust frequency
	folderInfo[8] = fullInfo[32][1]+fullInfo[33][1] // noncontact vibration amplitude
	n = SearchString(fullInfo,"XYScanner.Height.value")
	folderInfo[9] = fullInfo[n][1]+fullInfo[n+1][1] + " x " + fullInfo[n+34][1]+fullInfo[n+35][1] // scan range
	n = SearchString(fullInfo,"XYScanner.Lines.value")
	folderInfo[10] = fullInfo[n][1]+" x "+fullInfo[n+6][1] // number of points
	folderInfo[11] = fullInfo[SearchString(fullInfo,"X.physicalIncrement")][1] // x increment
	folderInfo[12] = fullInfo[SearchString(fullInfo,"Y.physicalIncrement")][1] // y increment
End

Proc checkInfo(ba) : ButtonControl
	string ba
	dowindow/f FileInfo
	if (V_flag!=1)
		FileInfo()
	endif
End

Function LineProfile(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	wave xCursors, yCursors,W_ImageLineProfile
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			WMCreateImageLineProfileGraph()
//			UpdateLineProfile()
//			CheckCursorMove()
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

Function UpdateLineProfile()
	wave xCursors, yCursors,W_ImageLineProfile
	string imageFile,windowName,cursorPositionX,cursorPositionY,lineProfile
	NVAR folderNumber
	SVAR scanMove
	variable cursorDistance,i,sizeOfProfile
	wave/T folderInfo
	sprintf windowName, "Image_"+scanMove
	for(i=1;i<6;i+=1)
		DoWindow/f $windowName
		if(strlen(CsrInfo($cursorEnum(2*i-1)))>0 && strlen(CsrInfo($cursorEnum(2*i)))>0)
			make/o W_ImageLineProfile
			make/O/N=2 xCursors,yCursors
			sprintf cursorPositionX, "xCursor"+cursorEnum(2*i-1)+cursorEnum(2*i)
			sprintf cursorPositionY, "yCursor"+cursorEnum(2*i-1)+cursorEnum(2*i)
			xCursors = {xcsr($cursorEnum(2*i-1)),xcsr($cursorEnum(2*i))}
			yCursors = {vcsr($cursorEnum(2*i-1)),vcsr($cursorEnum(2*i))}
			make/o/N=2 $cursorPositionX=xCursors
			make/o/N=2 $cursorPositionY=yCursors
			sprintf imageFile, "akw2d_"+scanMove
			ImageLineProfile srcWave=$imageFile, xWave=xCursors, yWave=yCursors
			DoWindow/f $windowName
			Checkdisplayed $cursorPositionY
			If(V_flag==0)
				AppendtoGraph $cursorPositionY vs $cursorPositionX
				ModifyGraph rgb($cursorPositionY)=(mod(i*13056, 65280),mod(i*13056*2, 65280),mod(i*13056*3, 65280))
			endif
			sprintf lineProfile, "lineProfileOfCursors"+cursorEnum(2*i-1)+cursorEnum(2*i)
			sizeOfProfile=DimSize(W_ImageLineProfile,0)
			make/o/N=(sizeOfProfile) $lineProfile=W_ImageLineProfile
			DoWindow/f LineProfileWindow
			If(V_flag==0)
				display
				DoWindow/c LineProfileWindow
				AppendToGraph $lineProfile
				ModifyGraph rgb($lineProfile)=(mod(i*13056, 65280),mod(i*13056*2, 65280),mod(i*13056*3, 65280))
			endif
			Checkdisplayed $lineProfile
			If(V_flag==0)
				AppendToGraph $lineProfile
				ModifyGraph rgb($lineProfile)=(mod(i*13056, 65280),mod(i*13056*2, 65280),mod(i*13056*3, 65280))
			endif
			cursorDistance=sqrt((xCursors[0]-xCursors[1])^2+(yCursors[0]-yCursors[1])^2)
			ModifyGraph muloffset={cursorDistance/sizeOfProfile,0}
			ModifyGraph margin(left)=36,margin(bottom)=29,margin(top)=7,margin(right)=7
			ModifyGraph tick=2
			Label left folderInfo[6];
		endif
	Endfor
End

Function CursorWindowHook(s)
	STRUCT WMWinHookStruct &s	
	Variable hookResult = 0	// 0 if we do not handle event, 1 if we handle it.
	switch(s.eventCode)
		case 5:
			UpdateLineProfile()// "mouseup"
			break
	endswitch

	return hookResult	// If non-zero, we handled event and Igor will ignore it.
End

Function CheckCursorMove()
	NVAR folderNumber
	SVAR scanMove
	string windowName
	sprintf windowName, "Image_"+scanMove
	DoWindow/f $windowName				
	SetWindow $windowName, hook(MyHook) = CursorWindowHook	// Install window hook
End

Function SearchString(bag,apple)
	wave/T bag
	string apple
	variable i=1, rowDimension
	rowDimension = DimSize(bag,0)
	for(i=1;i<=rowDimension;i+=1)
		if(cmpstr(bag[i][0],apple)==0)
			return i
		endif
	endfor
	return NaN
End

Function/S scanMoveEnum(n)
	variable n
	Switch(n)
		case 1:
			return "Up"
		case 2:
			return "ReUp"
		case 3:
			return "Down"
		case 4:
			return "ReDown"
		default:
			return ""
	endswitch
End

Function/S cursorEnum(n)
	variable n
	Switch(n)
		case 1:
			return "A"
		case 2:
			return "B"
		case 3:
			return "C"
		case 4:
			return "D"
		case 5:
			return "E"
		case 6:
			return "F"
		case 7:
			return "G"
		case 8:
			return "H"
		case 9:
			return "I"
		case 10:
			return "J"
		default:
			return ""
	endswitch
End

Function OffsetPlane(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	variable n, zRange
	string tempWaveName,rangeLabel, tempWindowName
	wave offsetWave, W_coef
	wave/T folderInfo
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			for(n=1;n<=4;n+=1)
				sprintf tempWaveName, "akw2d_"+scanMoveEnum(n)
				offset2DWave($tempWaveName)
				sprintf tempWindowName, "Image_"+scanMoveEnum(n)
				Dowindow/f $tempWindowName
				zRange = WaveMax($tempWaveName)-WaveMin($tempWaveName)
				sprintf rangeLabel, "Z Range: %.3g" + folderInfo[6], zRange
				TextBox/C/N=text0/F=0/S=3/B=1/A=LT/X=0.00/Y=0.00 rangeLabel
			endfor
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

// Suppose this target 2D wave is m * n. Offset this wave so that if there's an
// array of size n with its elements are sum of each row, a linear fit on this array
// will give us slope 0; Also, if there's an array of size m with its elements are sum
// of each column, a linear fit on this array will give us slope 0 as well.
Function offset2DWave(target)
	Wave target
	
	Wave W_coef
	Variable sizeOfWave, i, j, ySlope, xSlope, averageHeight
	duplicate/o target offsetWave
	sizeOfWave=DimSize(offsetWave,0)
	make/O/N=(sizeOfWave) ylineToFit=0
	make/O/N=(sizeOfWave) xlineToFit=0
	for(i=0;i<sizeOfWave;i+=1)
		for(j=0;j<sizeOfWave;j+=1)
			if (numtype(offsetWave[i][j]) != 2)
				ylineToFit[i]+=offsetWave[i][j]
			endif
		endfor
	endfor
	CurveFit/Q line ylineToFit
	ySlope=W_coef[1]/sizeOfWave
	averageHeight=mean(target)
	for(i=0;i<sizeOfWave;i+=1)
		for(j=0;j<sizeOfWave;j+=1)
			if (numtype(offsetWave[i][j]) != 2)
				offsetWave[i][j]=offsetWave[i][j]-i*ySlope
			endif
		endfor
	endfor
	for(i=0;i<sizeOfWave;i+=1)
		for(j=0;j<sizeOfWave;j+=1)
			if (numtype(offsetWave[j][i]) != 2)
				xlineToFit[i] += offsetWave[j][i]
			endif
		endfor
	endfor
	CurveFit/Q line xlineToFit
	xSlope=W_coef[1]/sizeOfWave
	averageHeight=mean(offsetWave)
	for(i=0;i<sizeOfWave;i+=1)
		for(j=0;j<sizeOfWave;j+=1)
			if (numtype(offsetWave[i][j]) != 2)
				offsetWave[i][j]=offsetWave[i][j]-j*xSlope
			endif
		endfor
	endfor
	duplicate/o offsetWave target
End

Function SaveImage(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	string imageName0, imageName1, rangeLabel
	variable stringLength, i=0, zRange
	wave/T folderInfo

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			imageName0 = ImageNameList("","")
			stringLength = strlen(imageName0)
			imageName0 = imageName0[0,stringLength-2]
			do
				imageName1 = imageName0 + num2str(i)
				i+=1
			while(exists(imageName1)!=0)
			duplicate $imageName0 $imageName1
			Display
			AppendImage $imageName1;DelayUpdate
			ModifyImage $imageName1 ctab= {*,*,Terrain,0}
			zRange = WaveMax($imageName1)-WaveMin($imageName1)
			sprintf rangeLabel, "Z Range: %.3g" + folderInfo[6], zRange
			TextBox/C/N=text0/F=0/S=3/B=1/A=LT/X=0.00/Y=0.00 rangeLabel
			ModifyGraph tick=2
			ModifyGraph margin(left)=36,margin(bottom)=29,margin(top)=7,margin(right)=7
			ModifyGraph width={Aspect,1}
			 
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function AddScaleBar(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			make/o/n=(4,2) scale
			scale[0][0] = 8e-7
			scale[1][0] = 7e-7
			scale[2][0] = 7e-7
			scale[3][0] = 8e-7
			scale[0][1] = 5e-7
			scale[1][1] = 5e-7
			scale[2][1] = 15e-7
			scale[3][1] = 15e-7
			AppendToGraph scale[][0] vs scale[][1]
			TextBox/C/N=text1/F=0/S=3/A=MC "1µm"
			TextBox/C/N=text1/B=1
			TextBox/C/N=text1/X=-33.00/Y=-41.00
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Load(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			openAllFiles()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function removeLoad(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	NVAR loadingNum
	Wave/T loadingInfo
	string dataFolder
	Variable i
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			if (loadingNum >= DimSize(loadingInfo, 0) || cmpstr(loadingInfo[loadingNum][0], "") == 0)
				print "This file set is not loaded, cannot remove!"
			else
				for(i = 1; i <= str2num(loadingInfo[loadingNum][2]); i += 1)
					sprintf dataFolder, ":fileSet%d_%.5d", loadingNum, i
					KillDataFolder $dataFolder
				endfor
				loadingInfo[loadingNum][] = ""
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function scanIdChanged(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	NVAR loadingNum
	String folderHash = "folderHash" + num2str(loadingNum)
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			updateFolderNumber($folderHash)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function folderNumberChanged(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			updateImage()
			setScanIDFromFN()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

// set scan ids base on folder number
Function setScanIDFromFN()
	Wave/T fullInfo
	NVAR runCycleCount, scanCycleCount, channel
	runCycleCount = str2num(fullInfo[SearchString(fullInfo,"runCycleCount")][1])
	scanCycleCount = str2num(fullInfo[SearchString(fullInfo,"scanCycleCount")][1])
	channel = channelNameToInt(fullInfo[SearchString(fullInfo,"channelName")][1])
	DoWindow/F AFMdataAnalyzer
	PopupMenu channelNameMenu,mode=channel+1
End

Function buildPuzzle(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			startImagePuzzle()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function channelNameMenuSelected(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	
	NVAR loadingNum, channel
	String folderHash = "folderHash" + num2str(loadingNum)
	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			channel = popNum - 1
			updateFolderNumber($folderHash)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
