#pragma rtGlobals=3		// Use modern global access method and strict wave access.
Function/S createHexagon(size)
	Variable size
	
	Variable i = 0
	String hexagon = "hexagon", hexName
	do
		hexName = hexagon + num2str(i)
		i += 1
	while(WaveExists($hexName))
	make $hexName
	buildShape($hexName, 6, size)
	return hexName
End

// build a shape with certain num of sides
Function buildShape(shape, numOfSides, length)
	Wave shape
	Variable numOfSides, length
	
	Redimension/N=(numOfSides, 2) shape
	Variable i
	for (i = 0; i < numOfSides; i += 1)
		shape[i][0] = length * cos(i * 2 * pi / numOfSides)
		shape[i][1] = length * sin(i * 2 * pi / numOfSides)
	endfor
End

// duplicate pattern so that it is n fold symmetrized to origin
Function nFoldSymmtrize(pattern, points, n)
	Wave pattern
	Variable points, n

	Redimension/N=(points * n, 2) pattern
	variable i
	for (i = points; i < points * n; i += 1)
		pattern[i][0] = pattern[i - points][0] * cos(2 * pi / n) - pattern[i - points][1] * sin(2 * pi / n)
		pattern[i][1] = pattern[i - points][0] * sin(2 * pi / n) + pattern[i - points][1] * cos(2 * pi / n)
	endfor
End

// move shape with vector (x, y)
Function moveShape(shape, x0, y0)
	Wave shape
	Variable x0, y0
	
	Variable i
	shape[][0] += x0
	shape[][1] += y0
End

// rotate shape counterclockwise angle
Function rotateShape(shape, angle)
	Wave shape
	Variable angle

	Variable i, j, x, y
	for (i = 0; i < DimSize(shape,0); i += 1)
		x = shape[i][0]
		y = shape[i][1]
		shape[i][0] = x * cos(angle) - y * sin(angle)
		shape[i][1] = x * sin(angle) + y * cos(angle)
	endfor
End

Function adjust6sqrt3Size(size)
	Variable size
	
	Wave hexagon2, hexagon3, hexagon4
	hexagon3 = 0
	hexagon3[1][0] = size
	hexagon3[2][0] = size / 2
	hexagon3[3][0] = size / 2 * 3
	hexagon3[2][1] = size / 2 * sqrt(3)
	hexagon3[3][1] = size / 2 * sqrt(3)
	moveShape(hexagon3, 0.5 - size / 2, (0.5 - size / 2) / sqrt(3))
	nFoldSymmtrize(hexagon3, 4, 6)
	
	moveShape(hexagon2, -1, 0)
	Variable oldSize = hexagon2[0][0]
	hexagon2 = hexagon2 / oldSize * size
	moveShape(hexagon2, 1, 0)
	hexagon2[6][0] = size
	nFoldSymmtrize(hexagon2, 7, 6)
	
	 buildShape(hexagon4, 6, size)
	 moveShape(hexagon4, 1.0825, 0.625)
	 nFoldSymmtrize(hexagon4, 6, 6)
End