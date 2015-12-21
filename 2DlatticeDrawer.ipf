#pragma rtGlobals=3		// Use modern global access method and strict wave access.

menu "Lattice Drawer"
	"Draw", latticeDrawer()
end

Window latticeDrawer() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(1375,257,1706,585) as "Draw 2D lattice"
	SetDrawLayer UserBack
	DrawLine 10,116,313,116
	SetVariable latticeConstantA,pos={20,20},size={90,20},proc=sizeChanged,title="a = "
	SetVariable latticeConstantA,limits={0,100,0.1},value= latticeConstants[0]
	SetVariable latticeConstantB,pos={20,50},size={90,20},proc=sizeChanged,title="b = "
	SetVariable latticeConstantB,limits={0,100,0.1},value= latticeConstants[1]
	PopupMenu latticeType,pos={130,20},size={190,28},proc=latticeTypeChange,title="lattice type"
	PopupMenu latticeType,mode=1,popvalue="Rectangular",value= #"\"Rectangular;Hexagonal\""
	SetVariable size,pos={20,80},size={90,20},proc=sizeChanged,title="size"
	SetVariable size,limits={1,100,1},value= size
	Button secondLayer,pos={20,135},size={90,20},proc=secondLayer,title="secondLayer"
	SetVariable Expand,pos={20,165},size={90,20},proc=layer0Changed,title="Expand"
	SetVariable Expand,limits={0.5,100,0.5},value= expand
	SetVariable rotation,pos={20,195},size={90,20},proc=layer0Changed,title="rotation"
	SetVariable rotation,limits={-360,360,1},value= rotation
	SetVariable xOffset,pos={20,225},size={90,20},proc=layer0Changed,title="xOffset"
	SetVariable xOffset,limits={-inf,inf,0.1},value= xOffset
	SetVariable yOffset,pos={20,255},size={90,20},proc=layer0Changed,title="yOffset"
	SetVariable yOffset,limits={-inf,inf,0.1},value= yOffset
	Button firstLayer,pos={130,59},size={90,20},proc=firstLayerSwitch,title="firstLayer"
	initialize()
EndMacro

Function initialize()
	// latticeType 0: rectangle, 1: hexagon
	Variable/G latticeType = 1, size = 10, expand = 1, rotation = 0, xOffset = 0, yOffset = 0
	make/N=(2, 2) layer, layer0
	make/N=2  latticeConstants = 1
	make/N=(7, 2) hexagon
	make/N=(5, 2) rectangle
End

Function latticeTypeChange(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	NVAR latticeType, size
	Wave layer, layer0
	
	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			if (stringmatch(popStr, "Rectangular"))
				latticeType = 0
			elseif (stringmatch(popStr, "Hexagonal"))
				latticeType = 1	
			endif
			update1stLayer()
			break
		case -1: // control being killed
			break
	endswitch
	return 0
End

Function update1stLayer()
	NVAR size
	Wave layer, layer0

	build(layer, size)
	draw(layer)
	CheckDisplayed/W=lattice layer0
	if (V_flag != 0)
		update2ndLayer()
	endif
End

Function buildRectangle()
	Wave rectangle, latticeConstants
	rectangle[0][0] = latticeConstants[0] / 2
	rectangle[0][1] = latticeConstants[1] / 2
	rectangle[1][0] = - latticeConstants[0] / 2
	rectangle[1][1] = latticeConstants[1] / 2
	rectangle[2][0] = - latticeConstants[0] / 2
	rectangle[2][1] = - latticeConstants[1] / 2
	rectangle[3][0] = latticeConstants[0] / 2
	rectangle[3][1] = - latticeConstants[1] / 2
	rectangle[4][0] = latticeConstants[0] / 2
	rectangle[4][1] = latticeConstants[1] / 2
End

Function buildHexgon()
	Wave hexagon, latticeConstants
	hexagon[][0] = cos(x * pi / 3 + pi / 6) / sqrt(3) * latticeConstants[0]
	hexagon[][1] = sin(x * pi / 3 + pi / 6) / sqrt(3) * latticeConstants[0]
End

Function build(latticeWave, size)
	Wave latticeWave
	Variable size
	NVAR latticeType
	
	Variable i, j, k
	Wave rectangle, hexagon, latticeConstants
	Redimension/N=(size * size * (6 + latticeType * 2), 2) latticeWave
	for (i = 0; i < size; i += 1)
		for (j = 0; j < size; j += 1)
			if (latticeType == 0)
				buildRectangle()
				for (k = 0; k < 5; k += 1)
					latticeWave[(i * size + j) * 6 + k][0] = rectangle[k][0] + i * latticeConstants[0]
					latticeWave[(i * size + j) * 6 + k][1] = rectangle[k][1] + j * latticeConstants[1]
				endfor
			else
				buildHexgon()
				for (k = 0; k < 7; k += 1)
					latticeWave[(i * size + j) * 8 + k][0] = hexagon[k][0] + (i + j * cos(pi / 3)) * latticeConstants[0]
					latticeWave[(i * size + j) * 8 + k][1] = hexagon[k][1] + (j * sin(pi / 3)) * latticeConstants[0]
				endfor		
			endif
			latticeWave[(i * size + j) * (6 + latticeType * 2) + k] = NaN	
		endfor
	endfor
	if (latticeType == 0)
		latticeWave[][0] = latticeWave[x][0] - size * latticeConstants[0] / 2
		latticeWave[][1] = latticeWave[x][1] - size * latticeConstants[1] / 2
	else
		latticeWave[][0] = latticeWave[x][0] - size * latticeConstants[0] * 3 / 4
		latticeWave[][1] = latticeWave[x][1] - size * latticeConstants[0] * sqrt(3) / 4
	endif
End

Function draw(latticeWave)
	Wave latticeWave
	
	NVAR latticeType
	Wave latticeConstants
	if (CheckName("lattice", 6) == 0)
		display/N=lattice
	endif
	CheckDisplayed/W=lattice latticeWave
	if (V_flag == 0)
		AppendToGraph latticeWave[][1] vs latticeWave[][0]
		ModifyGraph mode=4,marker=19, msize=min(latticeConstants[0], latticeConstants[1]) * 2
		SetAxis/A
	endif	
End

Function sizeChanged(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	NVAR size, latticeType
	Wave layer, latticeConstants
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			if (latticeType == 1 && (latticeConstants[0] == dval || latticeConstants[1] == dval))
				latticeConstants = dval
			endif
			update1stLayer()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function secondLayer(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	Wave layer, layer0
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			if (CheckName("lattice", 6) == 0)
				display/N=lattice
			endif
			CheckDisplayed/W=lattice layer0
			if (V_flag == 0)
				update2ndLayer()
			else
				removeFromGraph layer0
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function layer0Changed(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	update2ndLayer()
	return 0
End

Function update2ndLayer()
	NVAR expand, rotation, size, xOffset, yOffset, latticeType
	Wave layer, layer0, latticeConstants
	build(layer0, round(size / expand))
	duplicate layer0 tmp
	Variable angle = rotation * pi / 180
	layer0[][0] = (tmp[x][0] * cos(angle) - tmp[x][1] * sin(angle)) * expand + xOffset
	layer0[][1] = (tmp[x][0] * sin(angle) + tmp[x][1] * cos(angle)) * expand + yOffset
	KillWaves  tmp
	draw(layer0)
	ModifyGraph rgb(layer0)=(0,0,52224)
End

Function firstLayerSwitch(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	Wave layer, layer0
	
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			if (CheckName("lattice", 6) == 0)
				display/N=lattice
			endif
			CheckDisplayed/W=lattice layer
			if (V_flag == 0)
				update1stLayer()
			else
				removeFromGraph layer
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
