self.options = {}

local startX, startY, lastX, lastY
local previewRect
local layerCache

function options()
	self.options = {
		maxLevel = 5,
		ignoreFloorLayer = false,
		deleteBmp0Colors = false,
		deleteBmp1Colors = false,
		deleteRoomDefinitions = false
	}
	return {
		{ name = 'maxLevel', label = 'Delete level 0 through (1-32)', type = 'int', min = 1, max = 32, default = 5 },
		{ name = 'ignoreFloorLayer', label = 'Ignore Floor layer on level 0', type = 'bool', default = false },
		{ name = 'deleteBmp0Colors', label = 'Delete BMP0 colors', type = 'bool', default = false },
		{ name = 'deleteBmp1Colors', label = 'Delete BMP1 colors', type = 'bool', default = false },
		{ name = 'deleteRoomDefinitions', label = 'Prepare RoomDefs', type = 'bool', default = false }
	}
end

local function clearPreview()
	self:clearToolTiles()
	previewRect = nil
end

function setOption(name, value)
	if name == 'maxLevel' then
		value = math.max(1, math.min(32, math.floor(tonumber(value) or 5)))
	end
	self.options[name] = value
	if name == 'maxLevel' or name == 'ignoreFloorLayer' then
		layerCache = nil
		clearPreview()
	end
end

local function tileNumber(value)
	value = tonumber(value)
	if value then return math.floor(value) end
end

local function makeRect(x1, y1, x2, y2)
	x1, y1 = tileNumber(x1), tileNumber(y1)
	x2, y2 = tileNumber(x2), tileNumber(y2)
	if not x1 or not y1 or not x2 or not y2 then return end

	local left = math.min(x1, x2)
	local top = math.min(y1, y2)
	local right = math.max(x1, x2)
	local bottom = math.max(y1, y2)
	local mapWidth, mapHeight = map:width(), map:height()
	if right < 0 or bottom < 0 or left >= mapWidth or top >= mapHeight then return end

	left = math.max(0, left)
	top = math.max(0, top)
	right = math.min(mapWidth - 1, right)
	bottom = math.min(mapHeight - 1, bottom)
	return {
		left = left,
		top = top,
		right = right,
		bottom = bottom,
		width = right - left + 1,
		height = bottom - top + 1
	}
end

local function tileLayers()
	local maxLevel = self.options.maxLevel or 5
	local ignoreFloor = self.options.ignoreFloorLayer == true
	if layerCache and layerCache.map == map and layerCache.maxLevel == maxLevel
		and layerCache.ignoreFloor == ignoreFloor then
		return layerCache
	end

	local foundLayers = {}
	for i = 0, map:layerCount() - 1 do
		local layer = map:layerAt(i)
		local tileLayer = layer:asTileLayer()
		if tileLayer then
			local baseName = layer:name()
			for level = 0, maxLevel do
				local name = level .. '_' .. baseName
				local found = map:layer(name)
				if found and found:asTileLayer() == tileLayer then
					if not ignoreFloor or name ~= '0_Floor' then
						table.insert(foundLayers, { name = name, layer = tileLayer })
					end
					break
				end
			end
		end
	end

	foundLayers.map = map
	foundLayers.maxLevel = maxLevel
	foundLayers.ignoreFloor = ignoreFloor
	layerCache = foundLayers
	return foundLayers
end

local function containsRect(outer, inner)
	return outer.left <= inner.left and outer.top <= inner.top
		and outer.right >= inner.right and outer.bottom >= inner.bottom
end

local function addedRects(outer, inner)
	local rects = {}
	local function add(left, top, width, height)
		if width > 0 and height > 0 then
			table.insert(rects, {
				left = left,
				top = top,
				right = left + width - 1,
				bottom = top + height - 1
			})
		end
	end

	add(outer.left, outer.top, outer.width, inner.top - outer.top)
	add(outer.left, inner.bottom + 1, outer.width, outer.bottom - inner.bottom)
	add(outer.left, inner.top, inner.left - outer.left, inner.height)
	add(inner.right + 1, inner.top, outer.right - inner.right, inner.height)
	return rects
end

local function occupiedTiles(layer, rects)
	local region = Region:new()
	local count = 0

	for _, rect in ipairs(rects) do
		for y = rect.top, rect.bottom do
			local first
			for x = rect.left, rect.right do
				if layer:tileAt(x, y) then
					count = count + 1
					first = first or x
				elseif first then
					region:unite(first, y, x - first, 1)
					first = nil
				end
			end
			if first then region:unite(first, y, rect.right - first + 1, 1) end
		end
	end
	return region, count
end

local function showPreview(x1, y1, x2, y2, growing)
	local rect = makeRect(x1, y1, x2, y2)
	if not rect then
		clearPreview()
		return
	end

	local rects
	if growing and previewRect and containsRect(rect, previewRect) then
		rects = addedRects(rect, previewRect)
		if #rects == 0 then return end
	else
		self:clearToolTiles()
		rects = { rect }
	end

	local empty = map:noneTile()
	for _, entry in ipairs(tileLayers()) do
		local region, count = occupiedTiles(entry.layer, rects)
		if count > 0 then self:setToolTile(entry.name, region, empty) end
	end
	previewRect = rect
end

local function eraseTiles(rect)
	local changed = false
	for _, entry in ipairs(tileLayers()) do
		local region, count = occupiedTiles(entry.layer, { rect })
		if count > 0 then
			entry.layer:erase(region)
			changed = true
		end
	end
	return changed
end

local function eraseBmp(index, rect)
	local bmp = map:bmp(index)
	local black = rgb(0, 0, 0).pixel
	local found = false

	for y = rect.top, rect.bottom do
		for x = rect.left, rect.right do
			if bmp:pixel(x, y) ~= black then
				found = true
				break
			end
		end
		if found then break end
	end
	if not found then return false end

	bmp:erase(rect.left, rect.top, rect.width, rect.height)
	return true
end

local function prepareRoomDefs(rect)
	if not self.options.deleteRoomDefinitions then return false end

	local selection = map:tileSelection()
	if selection and selection:rectCount() == 1 then
		local bounds = selection:boundingRect()
		if bounds:x() == rect.left and bounds:y() == rect.top
			and bounds:width() == rect.width and bounds:height() == rect.height then
			return false
		end
	end

	selection = Region:new()
	selection:unite(rect.left, rect.top, rect.width, rect.height)
	map:setTileSelection(selection)
	return true
end

local function erase(rect)
	clearPreview()
	local changed = eraseTiles(rect)
	if self.options.deleteBmp0Colors and eraseBmp(0, rect) then changed = true end
	if self.options.deleteBmp1Colors and eraseBmp(1, rect) then changed = true end
	if prepareRoomDefs(rect) then changed = true end
	if changed then
		self:applyChanges('pq Eraser')
		layerCache = nil
	end
end

function activate()
	startX = nil
	previewRect = nil
	layerCache = nil
end

function mousePressed(buttons, x, y)
	if buttons.right then
		startX = nil
		clearPreview()
	elseif buttons.left then
		startX, startY = tileNumber(x), tileNumber(y)
		lastX, lastY = startX, startY
		showPreview(startX, startY, lastX, lastY, false)
	end
end

function mouseMoved(buttons, x, y)
	local currentX, currentY = tileNumber(x), tileNumber(y)
	if not currentX or not currentY then return end

	if startX and buttons.left then
		if currentX ~= lastX or currentY ~= lastY then
			lastX, lastY = currentX, currentY
			showPreview(startX, startY, lastX, lastY, true)
		end
	elseif not startX and not buttons.right then
		local sameTile = previewRect and previewRect.width == 1 and previewRect.height == 1
			and previewRect.left == currentX and previewRect.top == currentY
		if not sameTile then showPreview(currentX, currentY, currentX, currentY, false) end
	end
end

function mouseReleased(buttons, x, y)
	if buttons.right then
		startX = nil
		clearPreview()
		return
	end
	if not buttons.left or not startX then return end

	local rect = makeRect(startX, startY, tileNumber(x) or lastX, tileNumber(y) or lastY)
	startX = nil
	if rect then erase(rect) else clearPreview() end
end
