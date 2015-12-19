#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Initialize puzzle variables, waves and window.
Function startImagePuzzle()
	Variable/g puzzlePartNumber, xOffset, length, yOffset, height, x0InPuzzle, y0InPuzzle, intensityMultiplier, intensityOffset, hidePart
	Wave puzzle, highlightArea
	Wave/t folderInfo
	Variable xIncrement, yIncrement
	if(!WaveExists(puzzle))
		make/N=(500, 500) puzzle		
	endif
	dowindow/f ImagePuzzle
	if (V_flag!=1)
		Execute "ImagePuzzle()"
	endif
	if (!WaveExists(highlightArea))
		make/N=(5,2) highlightArea
	endif
End

// Start puzzle panel
Window ImagePuzzle() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(1073,369,1298,684) as "ImagePuzzle"
	Button showPuzzle,pos={10,10},size={50,20},proc=showPuzzle,title="Show",fSize=12
	SetVariable part,pos={20,177},size={60,16},proc=partNumChanged,title="part"
	SetVariable part,fSize=12,limits={0,inf,1},value= puzzlePartNumber
	SetVariable xOffset,pos={20,227},size={90,16},proc=updatePositions,title="X Offset"
	SetVariable xOffset,fSize=12,limits={0,inf,1},value= xOffset
	SetVariable length,pos={20,247},size={90,16},proc=updatePositions,title="Length"
	SetVariable length,fSize=12,limits={0,inf,1},value= length
	SetVariable yOffset,pos={120,227},size={90,16},proc=updatePositions,title="Y Offset"
	SetVariable yOffset,fSize=12,limits={0,inf,1},value= yOffset
	SetVariable height,pos={120,247},size={90,16},proc=updatePositions,title="Height"
	SetVariable height,fSize=12,limits={0,inf,1},value= height
	SetVariable x0InPuzzle,pos={20,267},size={90,16},proc=updatePositions,title="X Pos"
	SetVariable x0InPuzzle,fSize=12,value= x0InPuzzle
	SetVariable y0InPuzzle,pos={120,267},size={90,16},proc=updatePositions,title="Y Pos"
	SetVariable y0InPuzzle,fSize=12,value= y0InPuzzle
	CheckBox hidePartCheckBox,pos={90,177},size={40,14},proc=hidePartChanged,title="Hide"
	CheckBox hidePartCheckBox,fSize=12,variable= hidePart
	Button addPart,pos={20,197},size={50,20},proc=addPartToPuzzle,title="Add"
	Button addPart,fSize=12
	Button clearPuzzle,pos={80,197},size={50,20},proc=clearRectInPuzzle,title="Clear"
	Button clearPuzzle,help={"Clears data in the red rectangular range of puzzle"}
	Button clearPuzzle,fSize=12
	Button removePart,pos={140,177},size={60,20},proc=removePartWave,title="Kill Part"
	Button removePart,fSize=12
	Button cutEdges,pos={20,125},size={90,20},proc=autoRedimensionPuzzle,title="Cut Edges"
	Button cutEdges,fSize=12
	Button reset,pos={80,100},size={50,20},proc=resetPuzzle,title="Reset",fSize=12
	GroupBox everyPart,pos={10,157},size={210,150},title="Parameters for each part"
	GroupBox allParts,pos={10,40},size={210,110},title="Parameters for all parts"
	SetVariable xOffsetForAll,pos={20,60},size={90,16},title="X Offset",fSize=12
	SetVariable xOffsetForAll,limits={0,inf,1},value= allXOffset
	SetVariable yOffsetForAll,pos={120,60},size={90,16},title="Y Offset",fSize=12
	SetVariable yOffsetForAll,limits={0,inf,1},value= allYOffset
	SetVariable lengthForAll,pos={20,80},size={90,16},title="Length",fSize=12
	SetVariable lengthForAll,limits={0,inf,1},value= allLength
	SetVariable heightForAll,pos={120,80},size={90,16},title="Height",fSize=12
	SetVariable heightForAll,limits={0,inf,1},value= allHeight
	Button goLeft,pos={148,120},size={20,20},proc=moveRect,title="\\W645"
	Button goDown,pos={168,120},size={20,20},proc=moveRect,title="\\W622"
	Button goUp,pos={168,100},size={20,20},proc=moveRect,title="\\W606"
	Button goRight,pos={188,120},size={20,20},proc=moveRect,title="\\W648"
	SetVariable intensityMultiplierController,pos={20,287},size={90,16},proc=adjustIntensity,title="k"
	SetVariable intensityMultiplierController,help={"intensity = k * x + b"}
	SetVariable intensityMultiplierController,limits={-inf,inf,0.1},value= intensityMultiplier
	SetVariable intensityOffsetControl,pos={120,287},size={90,16},proc=adjustIntensity,title="b"
	SetVariable intensityOffsetControl,limits={-inf,inf,20},value= intensityOffset
	Button updateAll,pos={20,100},size={50,20},proc=updateAll,title="Update"
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
					addImageToPuzzle(hs.winName)
					break
			endswitch
		break
	endswitch
	return 0	
End

// puzzleParts[i][] from left to right: 0. loading number, 1. folder number, 2. scan number (up, down, re_up, re_down)
// 3. x offset, 4. length, 5. y offset, 6. height, 7. x position in puzzle, 8. y position in Puzzle, 9. intensity multiplier,
// 10. intensity offset, 11. x increment, 12. y increment
Function addImageToPuzzle(windowName)
	String windowName
	
	String targetWaveName, destination
	Wave puzzleParts, highlightArea
	Wave/T folderInfo
	NVAR loadingNum, folderNumber, allXOffset, allLength, allYOffset, allHeight
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
	
	for(i = 0; i < DimSize(puzzleParts, 0); i += 1)
		if (puzzleParts[i][0] == loadingNum && puzzleParts[i][1] == folderNumber && puzzleParts[i][2] == scanMove)
			printf "This image is alreay added as part %d!\r", i
			return 0
		endif
	endfor
	for(i = 0; i < DimSize(puzzleParts, 0); i += 1)
		if (puzzleParts[i][1] == 0)
			break
		endif
		if (i == DimSize(puzzleParts, 0) - 1)
			Redimension/N=(DimSize(puzzleParts, 0) + 10, -1) puzzleParts
			i += 1
			break
		endif
	endfor
	if (!WaveExists(highlightArea))
		make/N=(5,2) highlightArea
	endif
	destination = "part" + num2str(i)
	puzzleParts[i][0] = loadingNum
	puzzleParts[i][1] = folderNumber
	puzzleParts[i][2] = scanMove
	puzzleParts[i][3] = allXOffset
	puzzleParts[i][4] = allLength
	puzzleParts[i][5] = allYOffset
	puzzleParts[i][6] = allHeight
	puzzleParts[i][7] = highlightArea[0][0] / str2num(folderInfo[11]) - allXOffset
	puzzleParts[i][8] = highlightArea[0][1] / str2num(folderInfo[12]) - allYOffset
	puzzleParts[i][9] = 1
	puzzleParts[i][11] = str2num(folderInfo[11])
	puzzleParts[i][12] = str2num(folderInfo[12])
	duplicate/o $targetWaveName $destination
	redimensionPuzzleIfNeeded(i)
	setPuzzleValues(i, $destination)
	displayPuzzle()
	checkdisplayed highlightArea
	If(V_flag==0)
		showHighlightArea(0, 0, allLength * puzzleParts[i][11], allHeight * puzzleParts[i][12])
	endif
End

// Set values of imagePart onto puzzle at given position.
Function setPuzzleValues(partNum, imagePart)
	Variable partNum
	Wave imagePart
	
	Wave puzzleParts, puzzle
	Variable i, j
	for (i = 0; i < puzzleParts[partNum][4]; i += 1)
		for (j =0; j < puzzleParts[partNum][6]; j += 1)
			puzzle[puzzleParts[partNum][7] + puzzleParts[partNum][3] + i][puzzleParts[partNum][8] + puzzleParts[partNum][5] + j] = puzzleParts[partNum][9] * imagePart[puzzleParts[partNum][3] + i][puzzleParts[partNum][5] + j] + puzzleParts[partNum][10]
		Endfor
	Endfor
End

// Dynamically redimension puzzle to meet the expansion need of it. Dimensions will always increase.
Function redimensionPuzzleIfNeeded(partNum)
	Variable partNum

	Wave puzzleParts, puzzle
	Variable i, j, offset
	if(!WaveExists(puzzle))
		make/N=(500, 500) puzzle		
	endif
	if (puzzleParts[partNum][7] < 0) // x position in puzzle < 0
		InsertPoints 0, -puzzleParts[partNum][7], puzzle
		offset = puzzleParts[partNum][7]
		for(i = 0; i < DimSize(puzzleParts, 0); i += 1)
			if (puzzleParts[i][1] > 0)
				puzzleParts[i][7] = puzzleParts[i][7] - offset
			endif
		endfor
	endif
	// 500 is typical number of points of a scan.
	if (puzzleParts[partNum][7] + 500 >=  DimSize(puzzle, 0))
		Redimension/N=(DimSize(puzzle, 0) + 500, -1) puzzle
	endif
	if (puzzleParts[partNum][8] < 0) // y position in puzzle < 0
		InsertPoints/M=1 0, -puzzleParts[partNum][8], puzzle
		offset = puzzleParts[partNum][8]
		for(i = 0; i < DimSize(puzzleParts, 0); i += 1)
			if (puzzleParts[i][1] > 0)
				puzzleParts[i][8] = puzzleParts[i][8] - offset
			endif
		endfor
	endif
	if (puzzleParts[partNum][8] + 500 >=  DimSize(puzzle, 1))
		Redimension/N=(-1, DimSize(puzzle, 1) + 500) puzzle
	endif
	updatePanelVars(partNum)
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
	Wave puzzle
	Wave/T folderInfo
	bringWindowToFront("createYourPuzzle")
	CheckDisplayed puzzle
	If(V_flag==0 && numtype(str2num(folderInfo[11])) != 2)
		AppendImage puzzle
		ModifyImage puzzle ctab= {*,*,Terrain,0}
		SetScale/P x 0, str2num(folderInfo[11]), "m", puzzle
		SetScale/P y 0, str2num(folderInfo[12]), "m", puzzle
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
	
	Wave puzzleParts
	Wave/T folderInfo
	String imageName = "part" + num2str(puzzlePartNumber)
	updatePuzzleParts(puzzlePartNumber)
	redimensionPuzzleIfNeeded(puzzlePartNumber)
	Variable x0 = (puzzleParts[puzzlePartNumber][3] + puzzleParts[puzzlePartNumber][7]) * puzzleParts[puzzlePartNumber][11]
	Variable y0 = (puzzleParts[puzzlePartNumber][5] + puzzleParts[puzzlePartNumber][8]) * puzzleParts[puzzlePartNumber][12]
	Variable x1 = x0 + puzzleParts[puzzlePartNumber][4] * puzzleParts[puzzlePartNumber][11], y1 = y0 + puzzleParts[puzzlePartNumber][6] * puzzleParts[puzzlePartNumber][12]
	showHighlightArea(x0, y0, x1, y1)
	moveImage(puzzlePartNumber)
End

// The left lower corner of highlight area is (x0, y0); and the right up corner of this area
// is (x1, y1)
Function showHighlightArea(x0, y0, x1, y1)
	Variable x0, y0, x1, y1
	
	Wave highlightArea
	if (!WaveExists(highlightArea))
		make/N=(5,2) highlightArea
	endif
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

Function updatePuzzleParts(partNum)
	Variable partNum
	Wave puzzleParts
	NVAR xOffset, length, yOffset, height, x0InPuzzle, y0InPuzzle, intensityMultiplier, intensityOffset
	
	puzzleParts[partNum][3] = xOffset
	puzzleParts[partNum][4] = length
	puzzleParts[partNum][5] = yOffset
	puzzleParts[partNum][6] = height
	puzzleParts[partNum][7] = x0InPuzzle
	puzzleParts[partNum][8] = y0InPuzzle
	puzzleParts[partNum][9] = intensityMultiplier
	puzzleParts[partNum][10] = intensityOffset
End

Function updatePanelVars(partNum)
	Variable partNum
	Wave puzzleParts
	NVAR xOffset, length, yOffset, height, x0InPuzzle, y0InPuzzle, intensityMultiplier, intensityOffset
	
	xOffset = puzzleParts[partNum][3]
	length = puzzleParts[partNum][4]
	yOffset = puzzleParts[partNum][5]
	height = puzzleParts[partNum][6]
	x0InPuzzle = puzzleParts[partNum][7]
	y0InPuzzle = puzzleParts[partNum][8]
	intensityMultiplier = puzzleParts[partNum][9]
	intensityOffset = puzzleParts[partNum][10]
End

Function moveImage(puzzlePartNumber)
	Variable puzzlePartNumber

	Wave puzzleParts
	Wave/T folderInfo
	NVAR x0InPuzzle, y0InPuzzle
	String imageName = "part" + num2str(puzzlePartNumber)
	SetScale/P x x0InPuzzle * puzzleParts[puzzlePartNumber][11], puzzleParts[puzzlePartNumber][11], "m", $imageName
	SetScale/P y y0InPuzzle * puzzleParts[puzzlePartNumber][12], puzzleParts[puzzlePartNumber][12], "m", $imageName
End

Function hidePartChanged(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	
	NVAR hidePart
	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			hidePartToggle()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function hidePartToggle()
	NVAR hidePart, puzzlePartNumber
	
	String partName = "part" + num2str(puzzlePartNumber)
	if (!WaveExists($partName))
		printf "The image part%d does not exist!\r", puzzlePartNumber
		return 0
	endif
	bringWindowToFront("createYourPuzzle")
	checkDisplayed $partName
	if (hidePart == 0 && V_flag == 0)
		appendImage $partName
		ModifyImage $partName ctab= {*,*,Terrain,0}
	elseif (hidePart == 1 && V_flag != 0)
		removeAllImagePartsFromGraph()
	endif
End

Function addPartToPuzzle(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			updatePuzzle()
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

Function updatePuzzle()
	NVAR puzzlePartNumber
	String imageName = "part" + num2str(puzzlePartNumber)
	
	setPuzzleValues(puzzlePartNumber, $imageName)
End

Function partNumChanged(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	NVAR puzzlePartNumber
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval, imageName = "part" + sval
			Wave puzzleParts
			Wave/T folderInfo
			NVAR hidePart
			if (dval >= DimSize(puzzleParts, 0))
				print "This part is not added!"
				puzzlePartNumber = DimSize(puzzleParts, 0) - 1
				break;
			elseif(puzzleParts[dval][1] == 0)
				print "This part is not added!"
				break;
			endif
			updatePanelVars(puzzlePartNumber)
			removeAllImagePartsFromGraph()
			if (hidePart == 0)
				AppendImage $imageName
				ModifyImage $imageName ctab= {*,*,Terrain,0}
				moveImage(puzzlePartNumber)
			endif
			Variable x0 = (puzzleParts[puzzlePartNumber][3] + puzzleParts[puzzlePartNumber][7]) * puzzleParts[puzzlePartNumber][11]
			Variable y0 = (puzzleParts[puzzlePartNumber][5] + puzzleParts[puzzlePartNumber][8]) * puzzleParts[puzzlePartNumber][12]
			Variable x1 = x0 + puzzleParts[puzzlePartNumber][4] * puzzleParts[puzzlePartNumber][11], y1 = y0 + puzzleParts[puzzlePartNumber][6] * puzzleParts[puzzlePartNumber][12]
			showHighlightArea(x0, y0, x1, y1)
			redimensionPuzzleIfNeeded(puzzlePartNumber)
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

Function clearRectInPuzzle(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	NVAR xOffset, length, yOffset, height, x0InPuzzle, y0InPuzzle
	Wave puzzle
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			Variable i, j
			for (i = 0; i < length; i += 1)
				for (j = 0; j < height; j += 1)
					puzzle[x0InPuzzle + xOffset + i][y0InPuzzle + yOffset + j] = 0
				endfor
			endfor
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function removePartWave(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	NVAR puzzlePartNumber
	Wave puzzleParts
	String partName = "part" + num2str(puzzlePartNumber)
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			if (puzzleParts[puzzlePartNumber][1])
				puzzleParts[puzzlePartNumber] = 0
				KillWaves $partName
			else
				print "This part does not exist!"
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function autoRedimensionPuzzle(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			cutPuzzleEdges()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function cutPuzzleEdges()
	Wave puzzle, puzzleParts, highlightArea
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
			puzzleParts[i][7] = puzzleParts[i][7] - emptyRows
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
			puzzleParts[i][8] = puzzleParts[i][8] - emptyColomns
		endif
	endfor
	
	highlightArea[][0] = highlightArea[x][0] - emptyRows * puzzleParts[0][11]
	highlightArea[][1] = highlightArea[x][1] - emptyColomns * puzzleParts[0][12]
	//showHighlightArea(highlightArea[0][0], highlightArea[0][1], highlightArea[2][0], highlightArea[2][1])
	
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
	emptyRows = 0
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
	Wave puzzle
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			puzzle = 0
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
			Wave highlightArea
			Wave/T folderInfo
			NVAR allXOffset, allYOffset, allLength, allHeight
			Variable length = highlightArea[2][0] - highlightArea[0][0]
			Variable height = highlightArea[2][1] - highlightArea[0][1]
			if (cmpstr(ba.ctrlName, "goLeft") == 0)
				highlightArea[][0] -= length
			elseif (cmpstr(ba.ctrlName, "goRight") == 0)
				highlightArea[][0] += length
			elseif (cmpstr(ba.ctrlName, "goUp") == 0)
				highlightArea[][1] += height
			elseif (cmpstr(ba.ctrlName, "goDown") == 0)
				highlightArea[][1] -= height
			else
				showHighlightArea(allXOffset * str2num(folderInfo[11]), allYOffset * str2num(folderInfo[12]), (allXOffset + allLength) * str2num(folderInfo[11]), (allYOffset + allHeight) * str2num(folderInfo[12]))
				break
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
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
	Wave puzzleParts, puzzle, highlightArea
	Variable i, oldLength, oldHeight
	String partName
	NVAR allXOffset, allLength, allYOffset, allHeight
	
	if (allXOffset + allLength > 500)
		print "Length is exceeding limit! (limit is 500, if not ture, please change procedure.)"
		return 0
	elseif (allYOffset + allHeight > 500)
		print "Height is exceeding limit! (limit is 500, if not ture, please change procedure.)"
		return 0
	endif
	
	puzzle = 0
	make/O/N=(DimSize(puzzleParts, 0)) size
	size = puzzleParts[x][4]
	oldLength = getMajorityElement(size)
	size = puzzleParts[x][6]
	oldHeight = getMajorityElement(size)
	for (i = 0; i < DimSize(puzzleParts, 0); i += 1)
		if (puzzleParts[i][1] > 0)
			puzzleParts[i][3] = allXOffset
			puzzleParts[i][4] = allLength
			puzzleParts[i][5] = allYOffset
			puzzleParts[i][6] = allHeight
			puzzleParts[i][7] = round(puzzleParts[i][7] / oldLength * allLength)
			puzzleParts[i][8] = round(puzzleParts[i][8] / oldHeight * allHeight)
			partName = "part" + num2str(i)
			redimensionPuzzleIfNeeded(i)
			setPuzzleValues(i, $partName)
		endif
	endfor
	showHighlightArea(allXOffset * puzzleParts[0][11], allYOffset * puzzleParts[0][12], (allXOffset + allLength) * puzzleParts[0][11], (allYOffset + allHeight) * puzzleParts[0][12])
End

// Get the most frequent positive number in array
Function getMajorityElement(array)
	Wave array
	
	Variable i, count = 0, element = 0
	for(i = 0; i < DImSize(array, 0); i += 1)
		if (array[i] > 0)
			if (count > 0)
				if (array[i] == element)
					count += 1
				else
					count -= 1
				endif
			else
				element = array[i]
				count += 1
			endif
		endif
	endfor
	return element
End


Function adjustIntensity(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	NVAR intensityMultiplier, puzzlePartNumber
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			if (intensityMultiplier == 0)
				print "The intensity multiplier cannot be 0!"
			else
				updatePuzzleParts(puzzlePartNumber)
				updatePuzzle()
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
