#pragma rtGlobals=1	// Use modern global access method.

Macro colorControl()
	if (WinType("colorScaleController") != 7)
		Variable/g reverseColorChecked, firstMin, firstMax, lastMin, lastMax, firstColorValue, lastColorValue
		colorScaleController()
	endif
	DoWindow/F colorScaleController
	setParemetersFromGraph()
End

Window colorScaleController() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(1280,190,1713,374) as "Color Scale Controller"
	SetDrawLayer UserBack
	SetDrawEnv fname= "MS Sans Serif",fsize= 16
	DrawText 20,72,"First Color"
	SetDrawEnv fname= "MS Sans Serif",fsize= 16
	DrawText 20,132,"Last Color"
	Slider lastColorController,pos={110,110},size={300,29},proc=adjustColor
	Slider lastColorController,limits={-104.413,384.519,0},variable= lastColorValue,vert= 0,ticks= 0
	Slider firstColorController,pos={110,50},size={300,29},proc=adjustColor
	Slider firstColorController,limits={-593.345,-104.413,0},variable= firstColorValue,vert= 0,ticks= 0
	SetVariable firstColorLowLimit,pos={110,80},size={90,24},proc=limitsChanged,title="Min"
	SetVariable firstColorLowLimit,fSize=16,value= firstMin
	SetVariable firstColorHighLimit,pos={320,80},size={90,24},proc=limitsChanged,title="Max"
	SetVariable firstColorHighLimit,fSize=16,value= firstMax
	SetVariable lastColorLowLimit,pos={110,140},size={90,24},proc=limitsChanged,title="Min"
	SetVariable lastColorLowLimit,fSize=16,value= lastMin
	SetVariable lastColorHighLimit,pos={320,140},size={90,24},proc=limitsChanged,title="Max"
	SetVariable lastColorHighLimit,fSize=16,value= lastMax
	CheckBox reverseColor,pos={20,20},size={118,20},proc=reverseColor,title="Reverse Color"
	CheckBox reverseColor,fSize=16,variable= reverseColorChecked
	PopupMenu colorTable,pos={200,20},size={200,28},proc=colorChanged,fSize=16
	PopupMenu colorTable,mode=7,value= #"\"*COLORTABLEPOP*\""
	Button autoSetColor,pos={145,20},size={50,20},proc=autoSetColor,title="Auto"
	SetVariable firstColorValueDisplay,pos={220,80},size={81,16},disable=2,title=" "
	SetVariable firstColorValueDisplay,limits={-inf,inf,0},value= firstColorValue
	SetVariable lastColorValueDisplay,pos={220,140},size={80,16},disable=2,title=" "
	SetVariable lastColorValueDisplay,limits={-inf,inf,0},value= lastColorValue
EndMacro

Function setParemetersFromGraph()
	NVAR reverseColorChecked, firstMin, firstMax, lastMin, lastMax, firstColorValue, lastColorValue
	String imageName = getWave0InTopGraph()
	String ctab = StringByKey("RECREATION", ImageInfo("",imageName, 0))
	reverseColorChecked = str2num(StringFromList(3, ctab, ","))
	firstColorValue = wavemin($imageName)
	lastColorValue = wavemax($imageName)
	firstMin = (3 * firstColorValue - lastColorValue) / 2
	firstMax = (firstColorValue + lastColorValue) / 2
	lastMin = firstMax
	lastMax = (-firstColorValue + 3 * lastColorValue) / 2
	print firstColorValue
	setSliderLimits("firstColorController", firstMin, firstMax)
	setSliderLimits("lastColorController", lastMin, lastMax)
End

// get the image name in the top window, assuming there's only one image in the window.
Function/S getWave0InTopGraph()
	String separator = ";"
	return StringFromList(0, ImageNameList("", separator), separator)
End

Function adjustColor(sa) : SliderControl
	STRUCT WMSliderAction &sa
	
	NVAR reverseColorChecked
	switch( sa.eventCode )
		case -1: // control being killed
			break
		default:
			if( sa.eventCode & 1 ) // value set
				Variable curval = sa.curval
				String imageName = getWave0InTopGraph()
				if (cmpstr(sa.ctrlName, "firstColorController") == 0)
					ModifyImage $imageName ctab= {curval, , ,reverseColorChecked}
				elseif (cmpstr(sa.ctrlName, "lastColorController") == 0)
					ModifyImage $imageName ctab= {, curval, ,reverseColorChecked}
				endif
			endif
			break
	endswitch

	return 0
End

Function setSliderLimits(sliderName, lowLimit, highLimit)
	String sliderName
	Variable lowLimit, highLimit
	Slider $sliderName,limits={lowLimit,highLimit,0}
End

Function reverseColor(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			String imageName = getWave0InTopGraph()
			ModifyImage $imageName ctab= {, , ,checked}
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function limitsChanged(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	NVAR firstMin, firstMax, lastMin, lastMax
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			setSliderLimits("firstColorController", firstMin, firstMax)
			setSliderLimits("lastColorController", lastMin, lastMax)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function colorChanged(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	
	NVAR reverseColorChecked
	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			String imageName = getWave0InTopGraph()
			ModifyImage $imageName ctab= {, ,$popStr, reverseColorChecked}
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function autoSetColor(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	NVAR reverseColorChecked, firstMin, firstMax, lastMin, lastMax
	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			setParemetersFromGraph()
			String imageName = getWave0InTopGraph()
			ModifyImage $imageName ctab= {*, *, , reverseColorChecked}
			setSliderLimits("firstColorController", firstMin, firstMax)
			setSliderLimits("lastColorController", lastMin, lastMax)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End