#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Initialize puzzle variables, waves and window.
Function startImagePuzzle()
	Variable/g puzzlePartNumber
	Wave puzzleParts
	Wave/t folderInfo
	createWave("puzzleParts", row = 15, column = 10)
	createWave("puzzle", row = 500, column = 500)
	createWave("highlightArea", row = 5, column = 2)
	// puzzleGlobal: 0. x points for each part, 1. y points for each part, 2. x increament, 3. y increament,
	// 4. x points of each part in puzzle, 5. y points of each part in puzzle, 6. row, 7. column
	createWave("puzzleGlobal", row = 10)
	dowindow/f ImagePuzzle
	if (V_flag!=1)
		Execute "ImagePuzzle()"
	endif
End

// Start puzzle panel
Window ImagePuzzle() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(1053,373,1268,589) as "ImagePuzzle"
	Button showPuzzle,pos={20,45},size={50,20},proc=showPuzzle,title="Show",fSize=12
	SetVariable runCycleCount2,pos={20,140},size={70,16},disable=2,title="Scan ID"
	SetVariable runCycleCount2,fSize=12,limits={1,inf,0},value= puzzleParts[0][9]
	SetVariable xOffset,pos={19,165},size={80,16},proc=updatePositions,title="X Offset"
	SetVariable xOffset,fSize=12,limits={0,inf,1},value= puzzleParts[0][3]
	SetVariable yOffset,pos={110,165},size={80,16},proc=updatePositions,title="Y Offset"
	SetVariable yOffset,fSize=12,limits={0,inf,1},value= puzzleParts[0][4]
	Button addPart,pos={95,140},size={50,20},proc=addPartToPuzzle,title="Update"
	Button addPart,fSize=12
	Button removePart,pos={150,140},size={50,20},proc=removePartWave,title="Kill"
	Button removePart,fSize=12
	Button reset,pos={140,45},size={50,20},proc=resetPuzzle,title="Reset",fSize=12
	GroupBox everyPart,pos={10,120},size={200,90},title="Parameters for each part"
	GroupBox allParts,pos={10,10},size={200,60},title="Parameters for all parts"
	SetVariable rowGlobal,pos={50,75},size={50,16},proc=XYChanged,title="X",fSize=12
	SetVariable rowGlobal,value= puzzleGlobal[6]
	SetVariable columnGlobal,pos={50,94},size={50,16},proc=XYChanged,title="Y"
	SetVariable columnGlobal,fSize=12,value= puzzleGlobal[7]
	SetVariable lengthForAll,pos={20,25},size={80,16},title="Length",fSize=12
	SetVariable lengthForAll,limits={0,inf,1},value= puzzleGlobal[4]
	SetVariable heightForAll,pos={110,25},size={80,16},title="Height",fSize=12
	SetVariable heightForAll,limits={0,inf,1},value= puzzleGlobal[5]
	Button goLeft,pos={110,95},size={20,20},proc=moveRect,title="\\W645"
	Button goDown,pos={130,95},size={20,20},proc=moveRect,title="\\W622"
	Button goUp,pos={130,75},size={20,20},proc=moveRect,title="\\W606"
	Button goRight,pos={150,95},size={20,20},proc=moveRect,title="\\W648"
	SetVariable intensityMultiplierController,pos={20,187},size={80,16},proc=adjustIntensity,title="Icoeff"
	SetVariable intensityMultiplierController,help={"intensity = k * x + b"}
	SetVariable intensityMultiplierController,limits={-inf,inf,0.1},value= puzzleParts[0][7]
	SetVariable intensityOffsetControl,pos={110,187},size={80,16},proc=adjustIntensity,title="Ioffset"
	SetVariable intensityOffsetControl,limits={-inf,inf,20},value= puzzleParts[0][8]
	Button updateAll,pos={80,45},size={50,20},proc=updateAll,title="Update"
EndMacro

// Allow customer defined right click menu
Function AllowSelectionInTopGraph()
	SetWindow kwTopWin hook(contextual) = ContextualWindowHook
End

// Customer defined right click menu
Function ContextualWindowHook(hs)
	STRUCT WMWinHookStruct &hs

	strswitch(hs.eventName)
		case "mousedown":
			Variable isContextualMenu = enoise(1)
			// a contextual click is a right-click on Windows or Mac OS X, or control-click on OS 9.
			if (hs.EventMod != 16 || isContextualMenu > 0)
				break // allow normal click handling
			endif
			String clickedTraceInfo = TraceFromPixel(hs.mouseLoc.h, hs.mouseLoc.v, "")
			PopupContextualMenu/C=(hs.mouseLoc.h, hs.mouseLoc.v) "Add to puzzle;"
			strswitch(S_selection)
				case "Add to puzzle":
					dowindow/f ImagePuzzle
					if (V_flag!=1)
						startImagePuzzle()
					endif
					addImageToPuzzle(hs.winName)
					break
			endswitch
		break
	endswitch
	return 0	
End

// Create a wave with name and dimensions if the name is not taken.
Function createWave(name, [row, column])
	String name
	Variable row, column
	if(!WaveExists($name))	
		if (!ParamIsDefault(column) && !ParamIsDefault(row))
			make/N=(row, column) $name
		elseif(!ParamIsDefault(row))
			make/N=(row) $name
		else
			make $name
		endif
	endif
End

// Find the first 0 in certain column, return the row of that 0.
// If all elements in the column are non-zero, redimension the table, return the next row.
// Table must be a 2D wave
Function findFirst0(table, column)
	Wave table
	Variable column
	
	Variable i
	for(i = 0; i < DimSize(table, 0); i += 1)
		if (table[i][column] == 0)
			return i
		endif
		if (i == DimSize(table, 0) - 1)
			Redimension/N=(DimSize(table, 0) + 10, -1) table
			return i + 1
		endif
	endfor
	return -1
End

// --------------- strat puzzleParts operations ---------------
// puzzleParts[i][] from left to right: 0. loading number, 1. folder number, 2. scan number (up, down, re_up, re_down)
// 3. x offset, 4 y offset, 5. puzzle row, 6. puzzle column, 7. intensity multiplier, 8. intensity offset, 9. scan ID
// puzzleParts[0] is the row reserved for the current part.
Function addPuzzlePart(value0, value1, value2, value3, value4, value5, value6, value7, value8, value9)
	Variable value0, value1, value2, value3, value4, value5, value6, value7, value8, value9
	Wave puzzleParts
	Variable partNum = findFirst0(puzzleParts, 1)
	puzzleParts[partNum][0] = value0
	puzzleParts[partNum][1] = value1
	puzzleParts[partNum][2] = value2
	puzzleParts[partNum][3] = value3
	puzzleParts[partNum][4] = value4
	puzzleParts[partNum][5] = value5
	puzzleParts[partNum][6] = value6
	puzzleParts[partNum][7] = value7
	puzzleParts[partNum][8] = value8
	puzzleParts[partNum][9] = value9
End

// Find the part number by row and column in puzzle. if no part is found, return -1.
Function getPartNum(row, column)
	Variable row, column
	Wave puzzleParts
	Variable i
	for (i = 1; i < DimSize(puzzleParts, 0); i += 1)
		if (puzzleParts[i][5] == row && puzzleParts[i][6] == column && puzzleParts[i][1] > 0)
			return i
		endif
	endfor
	return -1
End

// find the max non-negative number in a column.
Function getMaxInColumn(table, column)
	Wave table
	Variable column
	Variable i, maximum = -1
	For (i = 0; i < DimSize(table, 0); i += 1)
		maximum = max(maximum, table[i][column])
	Endfor
	return maximum
End
// --------------- end puzzleParts operations ---------------

Function addImageToPuzzle(windowName)
	String windowName
	
	String targetWaveName, destination
	Wave puzzleParts, highlightArea, puzzleGlobal
	Wave/T folderInfo
	NVAR loadingNum, folderNumber, puzzlePartNumber, runCycleCount
	Variable i, scanMove
	strswitch(windowName)
		case "Image_Up":
			targetWaveName = "akw2d_Up"
			scanMove = 1
			break
		case "Image_ReUp":
			targetWaveName = "akw2d_ReUp"
			scanMove = 2
			break
		case "Image_Down":
			targetWaveName = "akw2d_Down"
			scanMove = 3
			break
		case "Image_ReDown":
			targetWaveName = "akw2d_ReDown"
			scanMove = 4
			break
	endswitch
	
	if (puzzleGlobal[0] == 0)
		puzzleGlobal[0] = str2num(folderInfo[11])
		puzzleGlobal[1] = str2num(folderInfo[12])
		puzzleGlobal[2] = str2num(folderInfo[13])
		puzzleGlobal[3] = str2num(folderInfo[14])
		puzzleGlobal[4] = puzzleGlobal[0]
		puzzleGlobal[5] = puzzleGlobal[1]
	endif

	for(i = 0; i < DimSize(puzzleParts, 0); i += 1)
		if (puzzleParts[i][0] == loadingNum && puzzleParts[i][1] == folderNumber && puzzleParts[i][2] == scanMove)
			printf "This image is alreay added as part %d!\r", i
			return 0
		endif
	endfor
	
	Variable collision = getPartNum(puzzleGlobal[6], puzzleGlobal[7])
	if (collision >= 0)
		printf "Image %d is alreay at this position!\r", puzzleParts[collision][9]
		return 0
	endif
	
	// reserve the first row for the current part.
	puzzleParts[0][1] = 1
	puzzlePartNumber = findFirst0(puzzleParts, 1)
	destination = "part" + num2str(puzzlePartNumber)
	addPuzzlePart(loadingNum, folderNumber, scanMove, 0, 0, puzzleGlobal[6], puzzleGlobal[7], 1, 0, runCycleCount)
	puzzleParts[0] = puzzleParts[puzzlePartNumber][q]
	duplicate/o $targetWaveName $destination
	redimensionPuzzleIfNeeded(puzzlePartNumber)
	displayPuzzle()
	setPuzzleValues(puzzlePartNumber, $destination)
	checkdisplayed highlightArea
	If(V_flag==0)
		updateHA(puzzleGlobal[6], puzzleGlobal[7])
	endif
End

// Set values of imagePart onto puzzle at given position.
Function setPuzzleValues(partNum, imagePart)
	Variable partNum
	Wave imagePart
	
	Wave puzzleParts, puzzle, puzzleGlobal
	Variable i, j
	for (i = 0; i < min(puzzleGlobal[4], puzzleGlobal[0] - puzzleParts[partNum][3]); i += 1)
		for (j = 0; j < min(puzzleGlobal[5], puzzleGlobal[1] - puzzleParts[partNum][4]); j += 1)
			puzzle[puzzleParts[partNum][5] * puzzleGlobal[4] + i][puzzleParts[partNum][6] * puzzleGlobal[5] + j] = puzzleParts[partNum][7] * imagePart[puzzleParts[partNum][3] + i][puzzleParts[partNum][4] + j] + puzzleParts[partNum][8]
		Endfor
	Endfor
End

// Dynamically redimension puzzle to meet the expansion need of it. Dimensions will always increase.
Function redimensionPuzzleIfNeeded(partNum)
	Variable partNum
	Wave puzzleParts, puzzle, puzzleGlobal
	Variable i, j, offset

	if (puzzleParts[partNum][5] < 0) // row in puzzle < 0
		InsertPoints 0, -puzzleParts[partNum][5] * puzzleGlobal[4], puzzle
		offset = puzzleParts[partNum][5]
		for(i = 0; i < DimSize(puzzleParts, 0); i += 1)
			if (puzzleParts[i][1] > 0)
				puzzleParts[i][5] = puzzleParts[i][5] - offset
			endif
		endfor
	endif
	Variable maxSize = (puzzleParts[partNum][5] + 1) * puzzleGlobal[4]
	if (maxSize > DimSize(puzzle, 0))
		Redimension/N=(maxSize, -1) puzzle
	endif
	if (puzzleParts[partNum][6] < 0) // column in puzzle < 0
		InsertPoints/M=1 0, -puzzleParts[partNum][6] * puzzleGlobal[5], puzzle
		offset = puzzleParts[partNum][6]
		for(i = 0; i < DimSize(puzzleParts, 0); i += 1)
			if (puzzleParts[i][1] > 0)
				puzzleParts[i][6] = puzzleParts[i][6] - offset
			endif
		endfor
	endif
	maxSize = (puzzleParts[partNum][6] + 1) * puzzleGlobal[5]
	if (maxSize >  DimSize(puzzle, 1))
		Redimension/N=(-1, maxSize) puzzle
	endif
End

Function showPuzzle(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	Wave puzzle
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			displayPuzzle()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function displayPuzzle()
	Wave puzzle, puzzleGlobal
	bringWindowToFront("createYourPuzzle")
	CheckDisplayed puzzle
	If(V_flag==0 && numtype(puzzleGlobal[2]) != 2)
		AppendImage puzzle
		ModifyImage puzzle ctab= {*,*,Terrain,0}
		SetScale/P x 0, puzzleGlobal[2], "m", puzzle
		SetScale/P y 0, puzzleGlobal[3], "m", puzzle
	endif
End

// bring window with windowName to front, if not exist, create one.
Function bringWindowToFront(windowName)
	String windowName
	DoWindow/f $windowName
	If(V_flag==0)
		Display
		dowindow/c $windowName
	endif
End

Function updatePositions(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			xyPositionChanged()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function xyPositionChanged()
	NVAR puzzlePartNumber
	Wave puzzleParts, puzzleGlobal
	puzzleParts[puzzlePartNumber] = puzzleParts[0][q]
	hidePartToggle(0)
	moveImage(puzzlePartNumber)
End

// update highlight area by row and column
Function updateHA(row, column)
	Variable row, column
	Wave puzzleGlobal
	showHighlightArea(row * puzzleGlobal[4] * puzzleGlobal[2], column * puzzleGlobal[5] * puzzleGlobal[3], (row + 1) * puzzleGlobal[4] * puzzleGlobal[2], (column + 1) * puzzleGlobal[5] * puzzleGlobal[3])
End

// The left lower corner of highlight area is (x0, y0); and the right up corner of this area
// is (x1, y1)
Function showHighlightArea(x0, y0, x1, y1)
	Variable x0, y0, x1, y1
	
	Wave highlightArea
	highlightArea[0][0] = x0
	highlightArea[0][1] = y0
	highlightArea[1][0] = x0
	highlightArea[1][1] = y1
	highlightArea[2][0] = x1
	highlightArea[2][1] = y1
	highlightArea[3][0] = x1
	highlightArea[3][1] = y0
	highlightArea[4][0] = x0
	highlightArea[4][1] = y0
	bringWindowToFront("createYourPuzzle")
	checkDisplayed highlightArea
	If(V_flag == 0)
		AppendToGraph highlightArea[][1] vs highlightArea[][0]
	endif
End

Function moveImage(partNum)
	Variable partNum
	
	Wave puzzleParts, puzzleGlobal
	String imageName = "part" + num2str(partNum)
	Variable totalX = getMaxInColumn(puzzleParts, 6) + 1, totalY = getMaxInColumn(puzzleParts, 5) + 1
	ModifyGraph nticks(insertL)=0,nticks(insertB)=0,noLabel(insertL)=2,noLabel(insertB)=2;DelayUpdate
	ModifyGraph axisEnab(insertL)={puzzleParts[partNum][6] / totalX, (puzzleParts[partNum][6] + 1) / totalX};DelayUpdate
	ModifyGraph axisEnab(insertB)={puzzleParts[partNum][5] / totalY, (puzzleParts[partNum][5] + 1) / totalY};DelayUpdate
	ModifyGraph freePos(insertL)=0,freePos(insertB)=0
	SetAxis insertB puzzleParts[partNum][3] * puzzleGlobal[2],(puzzleParts[partNum][3] + puzzleGlobal[4]) * puzzleGlobal[2]
	SetAxis insertL puzzleParts[partNum][4] * puzzleGlobal[3],(puzzleParts[partNum][4] + puzzleGlobal[5]) * puzzleGlobal[3]
End

// hide = 0 is to display the part, hide = 1 is to hide the part
Function hidePartToggle(hide)
	Variable hide
	NVAR puzzlePartNumber
	
	Wave puzzleParts, puzzleGlobal
	String partName = "part" + num2str(puzzlePartNumber)
	if (!WaveExists($partName))
		printf "The image part%d does not exist!\r", puzzlePartNumber
		return 0
	endif
	bringWindowToFront("createYourPuzzle")
	checkDisplayed $partName
	if (hide == 0 && V_flag == 0)
		AppendImage/L=insertL/B=insertB $partName;DelayUpdate
		ModifyImage $partName ctab= {*,*,Terrain,0}
		moveImage(puzzlePartNumber)
	elseif (hide == 1 && V_flag != 0)
		removeAllImagePartsFromGraph()
	endif
End

Function addPartToPuzzle(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	NVAR puzzlePartNumber
	String imageName = "part" + num2str(puzzlePartNumber)
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			setPuzzleValues(puzzlePartNumber, $imageName)
			hidePartToggle(1)
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

Function removeAllImagePartsFromGraph()
	Variable i = 0
	bringWindowToFront("createYourPuzzle")
	String imageAppended = ImageNameList("",";")
	do
		String imageName = StringFromList(i, imageAppended)
		if (cmpstr(imageName[0,3], "part") == 0)
			RemoveImage $imageName
		endif
		i += 1
	while(cmpstr(imageName, "") != 0)
End

Function removePartWave(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	NVAR puzzlePartNumber
	Wave puzzleParts
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			if (puzzlePartNumber > 0 && puzzleParts[puzzlePartNumber][1])
				removeAllImagePartsFromGraph()
				clearArea(puzzlePartNumber)
				removePart(puzzlePartNumber)
				cutPuzzleEdges()
			else
				printf "Part %d does not exist!\r", puzzlePartNumber
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function clearArea(partNum)
	Variable partNum
	Wave puzzle, puzzleParts, puzzleGlobal
	Variable i, j
	for (i = 0; i < puzzleGlobal[4]; i += 1)
		for (j = 0; j < puzzleGlobal[5]; j += 1)
			puzzle[puzzleParts[partNum][5] * puzzleGlobal[4] + i][puzzleParts[partNum][6] * puzzleGlobal[5] + j] = 0
		endfor
	endfor
End

Function removePart(partNum)
	Variable partNum
	Wave puzzleParts
	String partName = "part" + num2str(partNum)
	
	KillWaves $partName
	puzzleParts[partNum][] = 0
End

Function removeAllParts()
	Wave puzzleParts
	Variable i
	For (i = 1; i < Dimsize(puzzleParts, 0); i += 1)
		if (puzzleParts[i][1] > 0)
			removePart(i)
		endif
	Endfor
	puzzleParts = 0
End

Function cutPuzzleEdges()
	Wave puzzle, puzzleGlobal, puzzleParts
	Variable i, j, nonEmpty = 0, emptyRows = 0, emptyColomns = 0
	
	for (i = 0; i < DimSize(puzzle, 0); i += 1)
		for (j = 0; j < DimSize(puzzle, 1); j += 1)
			if (puzzle[i][j] != 0)
				nonEmpty = 1
				break
			endif
		endfor
		if (nonEmpty)
			break
		else
			emptyRows += 1
		endif
	endfor
	DeletePoints 0,emptyRows, puzzle
	for (i = 0; i < DimSize(puzzleParts, 0); i += 1)
		if (puzzleParts[i][1] > 0)
			puzzleParts[i][5] = puzzleParts[i][5] - round(emptyRows / puzzleGlobal[4])
		endif
	endfor
	
	nonEmpty = 0
	for (j = 0; j < DimSize(puzzle, 1); j += 1)
		for (i = 0; i < DimSize(puzzle, 0); i += 1)
			if (puzzle[i][j] != 0)
				nonEmpty = 1
				break
			endif
		endfor
		if (nonEmpty)
			break
		else
			emptyColomns += 1
		endif
	endfor
	DeletePoints/M=1 0,emptyColomns, puzzle
	
	for (i = 0; i < DimSize(puzzleParts, 0); i += 1)
		if (puzzleParts[i][1] > 0)
			puzzleParts[i][6] = puzzleParts[i][6] - round(emptyColomns / puzzleGlobal[5])
		endif
	endfor
	
	nonEmpty = 0
	emptyColomns = 0
	
	for (j = DimSize(puzzle, 1) - 1; j >= 0; j -= 1)
		for (i = DimSize(puzzle, 0) - 1; i >= 0; i -= 1)
			if (puzzle[i][j] != 0)
				nonEmpty = 1
				break
			endif
		endfor
		if (nonEmpty)
			break
		else
			emptyColomns += 1
		endif
	endfor
	Redimension/N=(-1, DimSize(puzzle, 1) - emptyColomns) puzzle
	
	nonEmpty = 0
	for (i = DimSize(puzzle, 0) - 1; i >= 0; i -= 1)
		for (j = DimSize(puzzle, 1) - 1; j >= 0; j -= 1)
			if (puzzle[i][j] != 0)
				nonEmpty = 1
				break
			endif
		endfor
		if (nonEmpty)
			break
		else
			emptyRows += 1
		endif
	endfor
	Redimension/N=(DimSize(puzzle, 0) - emptyRows, -1) puzzle
End

Function resetPuzzle(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	Wave puzzle, puzzleGlobal
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			puzzle = 0
			puzzleGlobal = 0
			removeAllParts()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function moveRect(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			Wave puzzleGlobal
			if (cmpstr(ba.ctrlName, "goLeft") == 0)
				puzzleGlobal[6] -= 1
			elseif (cmpstr(ba.ctrlName, "goRight") == 0)
				puzzleGlobal[6] += 1
			elseif (cmpstr(ba.ctrlName, "goUp") == 0)
				puzzleGlobal[7] += 1
			elseif (cmpstr(ba.ctrlName, "goDown") == 0)
				puzzleGlobal[7] -= 1
			endif
			rowColumnChanged()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function rowColumnChanged()
	NVAR puzzlePartNumber, scanIDDisplay
	Wave puzzleParts, puzzleGlobal
	updateHA(puzzleGlobal[6], puzzleGlobal[7])
	puzzlePartNumber = getPartNum(puzzleGlobal[6], puzzleGlobal[7])
	removeAllImagePartsFromGraph()
	if (puzzlePartNumber >= 0)
		puzzleParts[0] = puzzleParts[puzzlePartNumber][q]
		scanIDDisplay = 0
		hidePartToggle(1)
	else
		puzzleParts[0] = 0
	endif
End


Function updateAll(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			updateAllParts()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function updateAllParts()
	Wave puzzleParts, puzzle, puzzleGlobal
	Variable i, oldLength, oldHeight
	String partName
	
	puzzle = 0
	for (i = 1; i < DimSize(puzzleParts, 0); i += 1)
		if (puzzleParts[i][1] > 0)
			partName = "part" + num2str(i)
			redimensionPuzzleIfNeeded(i)
			setPuzzleValues(i, $partName)
		endif
	endfor
	updateHA(0, 0)
	cutPuzzleEdges()
End

Function adjustIntensity(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	NVAR intensityMultiplier, puzzlePartNumber
	String imageName = "part" + num2str(puzzlePartNumber)
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			if (intensityMultiplier == 0)
				print "The intensity multiplier cannot be 0!"
			else
				xyPositionChanged()
				setPuzzleValues(puzzlePartNumber, $imageName)
				hidePartToggle(1)
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function XYChanged(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			rowColumnChanged()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
