(*
 Given a list of servers, spawns a matrix of iTerm2 terminals.
 Then, it connects (via SSH) to each server on the list.

 If you need to connect a lots of servers at the same time and
 then run the same command(s) on all of them, this is a time saver.

 Bonus: after connecting, type Cmd + Option + I to broadcast input
 to all panes in the current tab.

 Author: Jorge Morgado <jorge (at) morgado (dot) ch>
 Copyright (c)2018. All rights reserved.
 MIT License

 TODO:
 * Reduce the font size on every terminal based on the length of the server's list
*)

(*
  Function: __split
  Splits theString by theDelimiter and returns an array with the result.
*)
on __split(theString, theDelimiter)
	-- save delimiters to restore old settings
	set oldDelimiters to AppleScript's text item delimiters
	-- set delimiters to delimiter to be used
	set AppleScript's text item delimiters to theDelimiter
	-- create the array
	set theArray to every text item of theString
	-- restore the old setting
	set AppleScript's text item delimiters to oldDelimiters
	-- return the result
	return theArray
end __split

(*
  Function: __matrix_size
  Calculate the matrix size based on the number of terminals to open.
  The maximum number of rows and columns is also provided
  to guarantee the calculation does not exceed that size.
*)
on __matrix_size(nrTerminals, maxRows, maxCols)
	set c to 1
	repeat until c is maxCols + 1
		set r to 1
		repeat until r is maxRows + 1
			if c * r ³ nrTerminals then
				return {r, c}
			end if
			
			set r to r + 1
		end repeat
		
		set c to c + 1
	end repeat
	
	return {0, 0}
end __matrix_size

-- Ask for the list of servers to connect
set questionServers to display dialog Â
	"Enter the list of machines to connect (one per line):" default answer linefeed & linefeed
set answerServers to text returned of questionServers
(*
# For testing, comment the previous dialog section and set the max_servers below
set max_servers to 42
set answerServers to {"server1"}
repeat with i from 2 to max_servers
	copy "server" & i to the end of answerServers
end repeat
*)

-- Split the list of servers into an array
set listServers to my __split(answerServers, linefeed)

-- Get the size of the servers list
set sizeListServers to count of listServers

-- Pre-define some iTerm matrix sizes based on the amount of servers
if sizeListServers ² 2 then
	set MAX_COLS to 2
	set MAX_ROWS to 1
else if sizeListServers ² 6 then
	set MAX_COLS to 2
	set MAX_ROWS to 3
else if sizeListServers ² 9 then
	set MAX_COLS to 3
	set MAX_ROWS to 3
else if sizeListServers ² 16 then
	set MAX_COLS to 4
	set MAX_ROWS to 4
else if sizeListServers ² 25 then
	set MAX_COLS to 5
	set MAX_ROWS to 5
else
	#ÊIt doesn't support more than 42 terminals
	# Because I don't have a really BIG screen :-(
	set MAX_COLS to 6
	set MAX_ROWS to 7
end if

-- Calculate the matrix dimensions
set {rowsMatrix, colsMatrix} to my __matrix_size(sizeListServers, MAX_ROWS, MAX_COLS)

if rowsMatrix = 0 or colsMatrix = 0 then
	display dialog "Your list is too big for me! I only support up to " & (MAX_ROWS * MAX_COLS) & " servers. Exiting..." buttons ["OK"] default button 1
	error number -128
end if


-- Correct the number of terminals on the last column if needed
if rowsMatrix * colsMatrix > sizeListServers then
	set rowsLast to rowsMatrix - ((rowsMatrix * colsMatrix) - sizeListServers)
else
	set rowsLast to rowsMatrix
end if


-- The base position for the iTerm window. This is postion (X,Y) of the canvas.
set basePosX to 0
set basePosY to 0
set bottomPosX to (675 * colsMatrix) * 0.6
set bottomPosY to (440 * rowsMatrix)


-- Open an iTerm window (if running) or start the application (if not yet running)
if application "iTerm" is running then
	tell application "iTerm"
		create window with default profile
	end tell
else
	activate application "iTerm"
end if

tell application "iTerm"
	set current_window to current window
	
	# Resize the main window for the iTerm matrix
	tell current_window
		set bounds to {basePosX, basePosY, bottomPosX, bottomPosY}
	end tell
	
	set sessionID to 1
	
	# Split the main window into the calculated nr of columns
	repeat with c from 1 to colsMatrix - 1
		tell session sessionID of current tab of current_window
			split vertically with default profile
		end tell
		
		# Then, for each column, split it into the calculated nr or rows	
		repeat with r from 1 to rowsMatrix - 1
			tell session sessionID of current tab of current_window
				split horizontally with default profile
			end tell
			
			set sessionID to sessionID + 1
		end repeat
		
		set sessionID to sessionID + 1
	end repeat
	
	# Split the last column (this is a special case because the last
	# column might not have the same amount of rows; it can also be that
	# the last column is simultaneously the first and only column).
	repeat with r from 1 to rowsLast - 1
		tell session sessionID of current tab of current_window
			split horizontally with default profile
		end tell
		
		set sessionID to sessionID + 1
	end repeat
	
	(*
	log "-- <DEBUG> --------------------"
	log "=> total servers = " & sizeListServers
	log "MAX_ROWS   = " & MAX_ROWS
	log "MAX_COLS   = " & MAX_COLS
	log "rowsMatrix = " & rowsMatrix
	log "colsMatrix = " & colsMatrix
	log "rowsLast   = " & rowsLast
	log "-- </DEBUG> -------------------"
	*)
	
	(*
	# This is the simple case where it just opens a connection to each
	# server in order of the sessions. No glamour...
	repeat with n from 1 to (count of listServers)
		tell session n of current tab of current_window
			set serverName to item n of listServers
			-- write text "echo " & serverName
			write text "ssh " & serverName
			-- delay 1
		end tell
	end repeat
	*)
	
	# The calibration value is used for edge cases where the first sessionID1
	# computes to 0 (zero). For example, the case with 4 terminals.
	set calibration_value to 0
	
	# In this case, opens the connections "in pairs" (side-by-side).
	# It makes more sense for cases where the list of servers contains
	# pairs of servers (e.g., a cluster) in the right order. In this case,
	# connections are opened next to each other which it's easier to
	# compare both terminals (except on the last column which might have
	# less rows).
	set n to 1
	repeat with nrCol from 1 to colsMatrix by 2
		repeat with nrRow from 1 to rowsMatrix
			set sessionID1 to (nrCol * rowsMatrix) + nrRow - MAX_ROWS
			
			# Can't have sessionID zeor. Correct that to +1
			if sessionID1 = 0 then
				set calibration_value to 1
			end if
			
			set sessionID1 to sessionID1 + calibration_value
			set sessionID2 to sessionID1 + rowsMatrix
			
			if sessionID1 ² sizeListServers then
				tell session sessionID1 of current tab of current_window
					set serverName to item n of listServers
					-- write text "echo " & serverName
					-- log "echo " & serverName
					write text "ssh " & serverName
				end tell
				set n to n + 1
			end if
			
			if sessionID2 ² sizeListServers then
				tell session sessionID2 of current tab of current_window
					set serverName to item n of listServers
					-- write text "echo " & serverName
					-- log "echo " & serverName
					write text "ssh " & serverName
				end tell
				set n to n + 1
			end if
		end repeat
		
		delay 1
	end repeat
end tell
