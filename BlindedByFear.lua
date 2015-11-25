local Addon = CreateFrame("FRAME", "Blinded By Fear");

local track; 							--index in database
local genre;							--only this and its "subgenre" will be shown
local shuffle;							--shuffle mode
local playOnly;							--playOnly mode (artist/album/genre)

local bbfChannelID;						--channel id
local players = {}						--table with players that are in the channel, easier to track them

local musicDB;							--music database

-------------------------------------
--
-- Receives an addon message and subStrings it ready to be displayed into the chat
-- @param #string message: message that is sent by players (e.g.: Artist#Title#Genre)
-- @return #string : Artist - Title
--
-------------------------------------
local function toStringTrack(message)
	--hoping that songtitle (or artist) hasn't a "#"
	return select(1, string.match(message,"([^#]*)#([^#]*)")) .. " - " .. select(2, string.match(message,"([^#]*)#([^#]*)"));
end

-------------------------------------
--
-- Send an addon message to a player, it's just "SendAddonMessage()" with some params already set
-- @param #string message: message to send
-- @param #string player: which player to send
--
-------------------------------------
local function sendAddonMessageToPlayer(message, player)
	if(player == UnitName("player")) then
		return;
	end
	SendAddonMessage("BBF", message, "WHISPER", player)
end

-------------------------------------
--
-- Send an addon message to every player inside the players.table.
-- @param #string message: message that is sent to all the players (e.g.: Artist#Title#Genre)
--
-------------------------------------
local function sendMessageToAllPlayers(message)
	local numPlayers = getn(players);
	for i = 1, numPlayers do
		sendAddonMessageToPlayer(message, players[i]);
	end
end

-------------------------------------
--
-- Sets the id channel in bbfChannelID variable.
-- It also calls some WoW functions to trigger Channel events.
--
-------------------------------------
local function setChannelID()
	local numChannels = GetNumDisplayChannels();
	for i = 1, numChannels do
		if(select(1, GetChannelDisplayInfo(i)) == "BlindedByFear") then
			bbfChannelID = i;
			SetSelectedDisplayChannel(bbfChannelID);
			ListChannelByName("BlindedByFear");
			return;
		end
	end
end

-------------------------------------
--
-- "OnUpdate" function. Tracks when the music has ended.
-- It also sends the new song to everyone.
-- This timer is used as well to trigger Channel events in order to get the players in the channel.
--
-------------------------------------
local total = 9999;		--to accept any music on init. if it was 0, I had to wait a tracklength.
Addon:SetScript("OnUpdate", nil)

local function onUpdate(self, elapsed)
	total = total + elapsed;
	if(track == -1 or total >= musicDB[track].length) then
		SetSelectedDisplayChannel(bbfChannelID);
		ListChannelByName("BlindedByFear");
		if(shuffle) then
			track = math.random(0, getn(musicDB)-1);
			if(playOnly) then
				local i = 0;
				while(not string.match(strlower(musicDB[track].artist), strlower(playOnly)) and not string.match(strlower(musicDB[track].genre), strlower(playOnly))) do
					track = track + 1;			--to prevent multiple randoms, so 1 random then "+1" til the next
					if(track >= getn(musicDB)) then
						i = i + 1;
						track = 0;
						if(i == 2) then
							print("|cFFFFAA00BlindedByFear: |cFFFF3300playOnly is ON with \""..playOnly.."\", but couldn't find any artist/genre with that filter")
							break;			--2 rounds and no found, maybe filter is wrong
						end
					end
				end
			end
			playTrack(track);
		elseif(playOnly) then
			track = track + 1;
			local i = 0;
			print(playOnly)
			while(not string.match(strlower(musicDB[track].artist), strlower(playOnly)) and not string.match(strlower(musicDB[track].genre), strlower(playOnly))) do
				track = track + 1;
				if(track >= getn(musicDB)) then
					i = i + 1;
					track = 0;
					if(i == 2) then
						print("|cFFFFAA00BlindedByFear: |cFFFF3300playOnly is ON with \""..playOnly.."\", but couldn't find any artist/genre with that filter")
						break;			--2 rounds and no found, maybe filter is wrong
					end
				end
			end
			playTrack(track);
		else
			playTrack(track + 1);
		end
		--send "#" to separate fields, it will be subString'ed when the receives it.
		sendMessageToAllPlayers(musicDB[track].artist .. "#" .. musicDB[track].title .. "#" .. musicDB[track].genre);
	end
end

-------------------------------------
--
-- Plays track.
-- @param #string index: track's index in the database.lua
--
-------------------------------------
function playTrack(index)
	total = 0;
	track = index;
	if(not musicDB[track]) then
		print("|cFFFFAA00BlindedByFear: |cFFFF3300End of music list - starting from the beginning")
		track = 0;
	end
	BlindedByFearSV[UnitName("player")].track = track;
	PlayMusic("Interface\\Addons\\BlindedByFear\\Music\\" .. musicDB[track].artist .. " - " .. musicDB[track].title .. ".mp3");
	print("|cFFFFAA00BlindedByFear: |cFFFF3300".. musicDB[track].artist .." - ".. musicDB[track].title .."|r")
end

-------------------------------------
--
-- "OnEvent" function.
-- Events that are treated here are: "VARIABLES_LOADED", "PLAYER_LOGIN", "CHAT_MSG_ADDON", "CHAT_MSG_CHANNEL_NOTICE" and "CHANNEL_ROSTER_UPDATE".
--
-------------------------------------
Addon:SetScript("OnEvent", function(self, event, ...)
	if(event == "VARIABLES_LOADED") then
		if type(BlindedByFearSV) ~= "table" then
			BlindedByFearSV = {};
			BlindedByFearSV[UnitName("player")] = {};
			BlindedByFearSV[UnitName("player")].track, BlindedByFearSV[UnitName("player")].genre = 0, nil;
			BlindedByFearSV[UnitName("player")].shuffle, BlindedByFearSV[UnitName("player")].playOnly = false, nil;
		end
		if(BlindedByFearSV[UnitName("player")]) then
			track = (BlindedByFearSV[UnitName("player")].track or 0) - 1; -- "-1" because OnUpdate will get do "i+1", this is to get the real track
			genre = BlindedByFearSV[UnitName("player")].genre;
			shuffle = BlindedByFearSV[UnitName("player")].shuffle;
			playOnly = BlindedByFearSV[UnitName("player")].playOnly;
		else
			BlindedByFearSV[UnitName("player")] = {};
			BlindedByFearSV[UnitName("player")].track, BlindedByFearSV[UnitName("player")].genre = 0, nil;
			track = 0;
			genre = nil;
			shuffle = false;
			playOnly = nil;
		end
		musicDB = dbMusic;
		print("|cFFffffffBl|cffffeeccin|cffffdd99de|cFFFFcc66dB|cFFFFbb33yF|cFFFFaa00ea|cFFFFbb33r L|cFFFFcc66oa|cFFFFdd99de|cFFFFeeccd|r")
		Addon:SetScript("OnUpdate", onUpdate);
	elseif(event == "PLAYER_ENTERING_WORLD") then
		setChannelID();		--when player /reload's variables are deleted, so this trys to get when reload is done
		JoinTemporaryChannel("BlindedByFear", "")
		total = 9999;
	elseif(event == "CHAT_MSG_ADDON") then
		local prefix, message, channel, sender = ...;
		if(prefix == "BBF" and channel == "WHISPER") then
			if(message == "requestMusic") then
				sendAddonMessageToPlayer(musicDB[track].artist .. "#" .. musicDB[track].title .. "#" .. musicDB[track].genre, sender);
			elseif(genre and string.find(string.lower(message), string.lower(genre))) then
				print("|cFFFFAA00BlindedByFear: |cFFFFFF00" .. sender .. "|cFFFF3300 is now listening |cFFFFFF00".. toStringTrack(message));
			elseif(genre == nil) then	--no genre filter
				print("|cFFFFAA00BlindedByFear: |cFFFFFF00" .. sender .. "|cFFFF3300 is now listening |cFFFFFF00".. toStringTrack(message));
			end
		end
	elseif((event == "CHAT_MSG_CHANNEL_NOTICE" or event == "CHAT_MSG_CHANNEL_JOIN" or event == "CHAT_MSG_CHANNEL_LEAVE") and select(9, ...) == "BlindedByFear") then
		--triggered when players join/leave channel
		setChannelID();
	elseif(event == "CHANNEL_ROSTER_UPDATE" and select(1, ...) == bbfChannelID) then
		setChannelID();
		--wiping and getting the most "fresh" data everytime something happens in the Addon's channel
		table.wipe(players);
		for i = 1, select(2, ...) do
			local p = GetChannelRosterInfo(bbfChannelID, i);
			table.insert(players, p);
		end
	end
end);


SLASH_BlindedByFear1, SLASH_BlindedByFear2 = "/blindedbyfear", "/bbf";

-------------------------------------
--
-- Slash command function. All commands that addon recognizes are here.
-- @param #string cmd: the command that player calls
--
-------------------------------------
function SlashCmd(cmd)
	if (cmd:match"next") then
		playTrack(track + 1);
	elseif (cmd:match"prev") then
		playTrack(track - 1);
	elseif (cmd:match"set") then
		local index = tonumber(string.sub(cmd, select(2, string.find(cmd,"set")) + 1, -1));
		playTrack(index);
	elseif (cmd:match"whatsup") then
		setChannelID();
		print("|cFFFFAA00BlindedByFear: |cFFFF3300There are " .. getn(players) .. " people listening music|r")
		sendMessageToAllPlayers("requestMusic");
	elseif (cmd:match"genre") then
		genre = string.sub(cmd, select(2, string.find(cmd,"genre")) + 2, -1);
		if(genre == "nofilter") then
			genre = nil;
			print("|cFFFFAA00BlindedByFear: |cFFFF3300All songs will be shown|r")
		else
			print("|cFFFFAA00BlindedByFear: |cFFFF3300Now only show songs that contains \"" .. genre .. "\" in their genre|r")
		end
		BlindedByFearSV[UnitName("player")].genre = genre;
	elseif (cmd:match("shuffle")) then
		if(shuffle) then
			shuffle = false;
			print("|cFFFFAA00BlindedByFear: |cFFFF3300Shuffle mode deactivated|r")
		else
			shuffle = true;
			print("|cFFFFAA00BlindedByFear: |cFFFF3300Shuffle mode activated|r")
		end
		BlindedByFearSV[UnitName("player")].shuffle = shuffle;
	elseif (cmd:match("playOnly")) then
		playOnly = string.sub(cmd, select(2, string.find(cmd,"playOnly")) + 2, -1);
		if(playOnly == "nofilter") then
			playOnly = nil;
			print("|cFFFFAA00BlindedByFear: |cFFFF3300All songs will be played|r")
		else
			print("|cFFFFAA00BlindedByFear: |cFFFF3300Now only plays artist/songs/genre that contains \"" .. playOnly .. "\" in their names|r")
		end
		BlindedByFearSV[UnitName("player")].playOnly = playOnly;
	else -- if (cmd:match"help")
		print("|cFFFFAA00To use commands you need to type \"/bbf cmd\"|r");
		print("|cFFFFAA00BlindedByFear commands:|r")
		print("|cFFFFAA00\"bbf next\" - |cFFFF3300Plays next song|r")
		print("|cFFFFAA00\"bbf prev\" - |cFFFF3300Plays previous song|r")
		print("|cFFFFAA00\"bbf set i\" - |cFFFF3300Plays song at the position \"i\"|r")
		print("|cFFFFAA00\"bbf whatsup\" - |cFFFF3300Prints every player who's listening and the current song|r")
		print("|cFFFFAA00\"bbf genre x\" - |cFFFF3300Only show songs \"warnings\" with genre \"x\" - \"/bbf genre nofilter\" to show all songs again|r")
		print("|cFFFFAA00\"bbf shuffle\" - |cFFFF3300Toggles shuffle mode|r")
		print("|cFFFFAA00\"bbf playOnly x\" - |cFFFF3300Only play songs with artist or genre \"x\" - \"/bbf playOnly nofilter\" to play all songs again|r")
	end
end

SlashCmdList["BlindedByFear"] = SlashCmd;


Addon:RegisterEvent("VARIABLES_LOADED");
Addon:RegisterEvent("PLAYER_ENTERING_WORLD");
Addon:RegisterEvent("CHAT_MSG_ADDON");
Addon:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE");
Addon:RegisterEvent("CHAT_MSG_CHANNEL_LEAVE");
Addon:RegisterEvent("CHAT_MSG_CHANNEL_JOIN");
Addon:RegisterEvent("CHANNEL_ROSTER_UPDATE");
RegisterAddonMessagePrefix("BBF")
