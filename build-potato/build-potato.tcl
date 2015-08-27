
proc main {} {
	cd [file dirname [info script]]
	wm withdraw .
	wm title . "Build Potato"

	set translate [tk_messageBox -icon question -title "Build Potato" -message "Did you remember to update the translation files?" -type yesno]
	if { $translate ne "yes" } {
		exit;
	}

	bind . <F1> {console show}
	pack [text .t -yscrollcommand [list .sb set] -wrap word -width 120] -side left -expand 1 -fill both
	.t tag configure err -foreground red
	pack [scrollbar .sb -orient vertical -command [list .t yview]] -side left -expand 1 -fill y
	wm deiconify .
	update
	
	set vfsdir [file normalize [file join . build potato.vfs]]
	if { [file exists $vfsdir] } {
		catch {file delete -force ./potato.vfs}
		after 150
		file copy $vfsdir [set vfsdir [file join . potato.vfs]]
	} else {
		set vfsdir [file join . potato.vfs]
	}

	if { ![file exists $vfsdir] || ![file isdir $vfsdir] } {
		tk_messageBox -icon error -title "Build Potato" -message "potato.vfs not found!"
		exit;
	}
	
	set helpdir [file join $vfsdir lib help]
	if { ![file exists $helpdir] || ![file isdir $helpdir] } {
		set abort [tk_messageBox -icon warning -title "Build Potato" -message "The helpfiles seem to be missing. Abort?" -type yesno]
		if { $type ne "no" } {
			exit;
		}
	}

	# Find out what version we're building
	set vfile [file join $vfsdir lib potato-version.tcl]
	if { ![file exists $vfile] || [catch {source $vfile} potato_version] } {
		tk_messageBox -icon error -title "Build Potato" -message "Unable to locate Potato version!"
		exit;
	}

	set buildsdir [file join . builds]
	if { ![file exists $buildsdir] || ![file isdirectory $buildsdir] } {
		file mkdir $buildsdir
	}

	set destdir [file join $buildsdir $potato_version]
	if { [file exists $destdir] } {
		set ans [tk_messageBox -icon question -title "Build Potato" -message "Build dir already exists for this version ($potato_version). Delete and continue?" -type yesno]
		if { $ans ne "yes" } {
			exit;
		}
		file delete -force $destdir
		after 150
	}

	file mkdir $destdir

	set windowsRuntime [lindex [glob -directory . -nocomplain *base*x86.exe] 0]
	set win64Runtime [lindex [glob -directory . -nocomplain *base*64.exe] 0]
	set resHacker {C:\Program Files (x86)\Resource Hacker\ResHacker.exe}
	set rc {C:\Program Files (x86)\Microsoft SDKs\Windows\v7.1A\Bin\x64\RC.exe}
	set exe_name32 potato-$potato_version-win32.exe
	set exe_name64 potato-$potato_version-win32-x86_64.exe
	set 7zip {C:\Program Files\7-Zip\7z.exe}

	set built [list]
  
	if { ![file exists $windowsRuntime] } {
		set windowsRuntime [tk_getOpenFile -initialdir . -filetypes [list [list "Windows Executables" "*.exe"]] -title "Select 32-bit Windows Tcl Basekit..."]
	}

	if { ![file exists $win64Runtime] } {
		set win64Runtime [tk_getOpenFile -initialdir . -filetypes [list [list "Windows Executables" "*.exe"]] -title "Select 64-bit Windows Tcl Basekit..."]
	}
	
	if { ![file exists $resHacker] } {
		set resHacker [tk_getOpenFile -initialdir . -filetypes [list [list "Windows Executables" "*.exe"]] -title "Select Resource Hacker..."]
	}
	
	if { ![file exists $rc] } {
		set rc [tk_getOpenFile -initialdir . -filetypes [list [list "Windows Executables" "*.exe"]] -title "Select Resource Compiler (RC.exe)..."]
	}

	if { ![file exists $7zip] } {
		set 7zip [tk_getOpenFile -initialdir . -filetypes [list [list "Windows Executables" "*.exe"]] -title "Select 7Zip..."]
	}
	
	set skipWin 0
	set hasResHacker 1
	if { $resHacker eq "" || ![file exists $resHacker] || $rc eq "" || ![file exists $rc] } {
		set skipWin [tk_messageBox -info warning -message "Unable to modify Windows Executable resources. Skip Windows builds?" -title "Build Potato" -type yesno]
		set skipWin [expr { $skipWin eq "yes" }]
		set hasResHacker 0
	}
	
	
	if { $7zip eq "" || ![file exists $7zip] } {
		set skipSource 1
	} else {
		set skipSource 0
	}

	log "Building Potato $potato_version to [file nativename [file normalize $destdir]]...\n\n"
	
	if { !$skipWin } {
		log "Building Windows binaries..."
		
		if { $windowsRuntime ne "" && [file exists $windowsRuntime] } {
			log "Building Win32 .exe ..."
			exec [info nameofexecutable] [file normalize [file join . psdx.kit]] wrap potato.exe -runtime $windowsRuntime
			log "Win32 .exe built. Moving into version dir..."
	
			if { $hasResHacker } {
				file rename potato.exe [file join $destdir raw_potato.exe]
				log "Moved. Building Resource info..."
				set fid [open pres.rc.template r]
				set pres [read $fid]
				close $fid;
				set fid [open [file join $destdir pres.rc] w]
				puts -nonewline $fid [format $pres $potato_version [rhVers $potato_version] $exe_name32 "32-bit"]
				close $fid;
				exec $rc [file normalize [file join . $destdir pres.rc]]
				update
				log "Resource info created. Editing resources..."
				set fid [open [file join $destdir reshacker.txt] w]
				puts $fid "\[FILENAMES\]"
				puts $fid "Exe=[file normalize [file join . $destdir raw_potato.exe]]"
				puts $fid "SaveAs=[file normalize [file join . $destdir $exe_name32]]"
				puts $fid "Log=[file normalize [file join . $destdir reshacker.log]]"
				puts $fid ""
				puts $fid "\[COMMANDS\]"
				puts $fid "-addoverwrite [file normalize [file join . Potato.ico]], ICONGROUP,TK,1033"
				puts $fid "-addoverwrite [file normalize [file join . $destdir pres.res]], VERSIONINFO,1,1033"
				close $fid;
				if { [pauseFor [file join . $destdir pres.res]] } {
					exec $resHacker -script [file normalize [file join . $destdir reshacker.txt]]
					update
					log "Resource Hacker finished. Waiting for $exe_name32 ..."
					if { [pauseFor [file join . $destdir $exe_name32]] } {
						log "Found. Win32 binary built.\n\n"
						lappend built [list [file join $destdir $exe_name32] "Win32 Binary"]
					}
				}
			} else {
				file rename potato.exe [file join $exe_name32]
				log "Moved. Unable to build resource info - you may wish to do so manually.\n\n"
				lappend built [list $exe_name32 "Win32 Binary (no resource info set)"]
			}
		}
		
		if { $win64Runtime ne "" && [file exists $win64Runtime] } {
			log "Building 64-bit Windows .exe ..."
			exec [info nameofexecutable] [file normalize [file join . psdx.kit]] wrap potato.exe -runtime $win64Runtime
			log "64-bit Windows .exe built. Moving into version dir..."
			if { $hasResHacker } {
				file rename potato.exe [file join $destdir raw_potato64.exe]
				log "Moved. Building Resource info..."
				set fid [open pres.rc.template r]
				set pres [read $fid]
				close $fid;
				set fid [open [file join $destdir pres.rc] w]
				puts -nonewline $fid [format $pres $destdir [rhVers $potato_version] $exe_name64 "64-bit"]
				close $fid;
				exec $rc [file normalize [file join . $destdir pres.rc]]
				update
				log "Resource info created. Editing resources..."
				set fid [open [file join $destdir reshacker.txt] w]
				puts $fid "\[FILENAMES\]"
				puts $fid "Exe=[file normalize [file join . $destdir raw_potato64.exe]]"
				puts $fid "SaveAs=[file normalize [file join . $destdir $exe_name64]]"
				puts $fid "Log=[file normalize [file join . $destdir reshacker64.log]]"
				puts $fid ""
				puts $fid "\[COMMANDS\]"
				puts $fid "-addoverwrite [file normalize [file join . Potato.ico]], ICONGROUP,TK,1033"
				puts $fid "-addoverwrite [file normalize [file join . $destdir pres.res]], VERSIONINFO,1,1033"
				puts $fid "-addoverwrite [file normalize [file join . manifest.xml]],24,1,1033"
				close $fid;
				if { [pauseFor [file join . $destdir pres.res]] } {
					exec $resHacker -script [file normalize [file join . $destdir reshacker.txt]]
					update
					log "Resource Hacker finished. Waiting for $exe_name64 ..."
					if { [pauseFor [file join . $destdir $exe_name64]] } {
						log "Done. Win64 binary built.\n\n"
						lappend built [list $exe_name64 "Win64 Binary"]
					}
				}
			} else {
				file rename potato.exe [file join $destdir $exe_name64]
				log "Moved. Unable to build resource info - you may wish to do so manually.\n\n"
				lappend built [list [file join $destdir $exe_name64] "Win64 Binary (no resource info set)"]
			}
		}
		
	}

	log "Creating Starkit..."
	exec [info nameofexecutable] [file normalize [file join . psdx.kit]] wrap potato
	file rename potato [set starkit [file join $destdir potato-$potato_version.kit]]
	log "Done.\n\n"
	lappend built [list $starkit "Starkit"]

	if { $skipSource } {
		log "7Zip not found. Skipping source archives."
	} else {
		log "Creating source-code .zip ..."
		set zip [file normalize [file join . $destdir potato-$potato_version-src.zip]]
		if { [catch {exec $7zip a $zip $vfsdir -xr!.svn -tzip} err options] } {
			log "Error on zip: [dict get $options -errorcode] // $err" err
		} else {
			log "Done.\n\n"
			lappend built [list $zip "Zip source archive"]
		}

		log "Creating source-code .tar ..."
		set tar [file normalize [file join . $destdir potato-$potato_version-src.tar]]
		if { [catch {exec $7zip a $tar $vfsdir -xr!.svn -ttar} err options] } {
			log "Error on tar: [dict get $options -errorcode] // $err" err
		} else {
			log "Waiting for .tar..."
			if { [pauseFor $tar] } {
				log "Found. .gz'ing the .tar archive..."
				if { [catch {exec $7zip a "$tar.gz" $tar -tgzip} err options] } {
					tk_messageBox -message "Error on gzip: [dict get $options -errorcode] // $err"
				} else {
					log "Done.\n\n"
					lappend built [list $tar.gz "Source Tarball"]
				}
			}
		}
	}
	
	# Cleanup temporary files
	cd $destdir
	file delete pres.rc pres.res reshacker.txt raw_potato.exe reshacker.log raw_potato64.exe reshacker64.log $tar
	cd ..
	log "\n\nDone! Potato version $potato_version built."
	set len 0
	foreach x $built {
		foreach {path type} $x {
			if { [string length $type] > $len } {
				set len [string length $type]
			}
		}
	}
	incr len 3
	set spaces [string repeat " " $len]
	foreach x $built {
		foreach {path type} $x {
			log "[string range "$type$spaces" 0 $len] -> [file nativename [file normalize $path]]"
		}
	}

};# main

proc pauseFor {file} {
	log "Waiting for [file nativename [file normalize $file]]..."
	set counter 0
	for {set counter 0} {$counter < 20} {incr counter} {
		if { ![file exists $file] } {
			update
			after 500
		}
	}

	if { ![file exists $file] } {
		log "Error: We waited, but $file still doesn't exist.\n\n" err
		return 0
	}
	log "Got [file nativename [file normalize $file]]"
	return 1;
};# pauseFor

proc rhVers {vers} {

	regsub -all {[^0-9]+} $vers "," vers
	set vers [split $vers ","]
	set vers [concat $vers [list 0 0 0 0 0]]
	set vers [join [lrange $vers 0 3] ","]

	return $vers;

};# rhVers

proc log {text {tag ""}} {
	.t insert end "$text\n" $tag
	.t see end
	update
}

main
