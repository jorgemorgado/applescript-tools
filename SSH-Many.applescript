(*
  Spawn N-terminal window (using iTerm2).

  Author: Jorge Morgado <jorge (at) morgado (dot) ch>
  Copyright, (c)2016. All rights reserved.
  MIT License
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


-- Ask for the list of servers to connect
set questionServers to display dialog Â
	"Enter the list of machines to connect (one per line):" default answer linefeed & linefeed
set answerServers to text returned of questionServers

set questionSudo to display dialog Â
	"Do you also want sudo access?" buttons {"Yes", "No"} default button 1
set answerSudo to button returned of questionSudo


-- Ask if SUDO access is needed
if answerSudo is equal to "Yes" then
	-- If needed, ask for SUDO password on the remote systems
	set passDialog to display dialog Â
		"Please enter your SUDO password:" with title Â
		"SUDO Password" with icon caution Â
		default answer Â
		"" buttons {"Cancel", "OK"} default button 2 Â
		giving up after 295 Â
		with hidden answer
	
	-- Check if a password has been entred, if >0 chars or user has cancelled
	if length of (text returned of passDialog) is 0 then
		display dialog "You didn't enter a password! Exiting..." buttons ["OK"] default button 1
		error number -128
	else
		set sudoPassword to (text returned of passDialog)
	end if
end if


-- Split the list of servers into an array called listServers
set listServers to my __split(answerServers, linefeed)

-- Just for testing with a very long list of servers
--set listServers to {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20"}


-- The base position for the very fist window. This is postion (X,Y) of the
-- canvas. We start 23 pixels(?) to the top to account for th Mac OS X menu bar.
set basePosX to 0
set basePosY to 23

-- The step for the cascade effect. Always open the next window by
-- stepX to the right and stepY down.
set stepX to 40
set stepY to 25

-- Start iTerm is not yet running
if application "iTerm" is not running then
	activate application "iTerm"
end if

-- Once iTerm is running, proceed to create windows and position them in cascade
tell application "iTerm"
	repeat with n from 1 to (count of listServers)
		create window with default profile
		tell current window
			set posX to (basePosX + ((n - 1) * stepX))
			set posY to (basePosY + ((n - 1) * stepY))
			
			--set bounds to {posX, posY, 588, 384}
			set bounds to {posX, posY, 588 + (n * stepX), 384 + (n * stepY)}
			
			tell current session
				set rows to 24
				set columns to 80
				activate
				set serverName to item n of listServers
				write text "ssh " & serverName
				
				if answerSudo is equal to "Yes" then
					delay 2
					write text "sudo bash"
					delay 2
					write text sudoPassword
				end if
			end tell
		end tell
		delay 1
	end repeat
end tell
