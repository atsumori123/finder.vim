let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" nexus#get_exe_bufnr
"---------------------------------------------------------------
function! nexus#get_exe_bufnr() abort
	return b:exe_bufnr
endfunction

"---------------------------------------------------------------
" open_window
"---------------------------------------------------------------
function! s:open_window() abort
	if type(get(b:, "exe_bufnr", v:true)) != v:t_bool
		call clearmatches(0)
		return
	endif
	let bufnr = bufnr("%")

	enew
	execute 'silent keepalt file -nexus-'
	setlocal modifiable
	setlocal filetype=nexus
	setlocal buftype=nofile
	setlocal bufhidden=wipe
	setlocal noswapfile
	setlocal nowrap
	setlocal cursorline

	let b:exe_bufnr = bufnr
endfunction

"---------------------------------------------------------------
" nexus#explorer
"---------------------------------------------------------------
function! nexus#explorer(...) abort
	let start_dir = exists("b:E.current_dir") ? b:E.current_dir : resolve(get(a:000, 0, getcwd()))
	if !isdirectory(start_dir)
		call nexus#utils#msg("Error", printf("Directory %s doesn't exist.", start_dir))
	endif

	if nexus#utils#is_nexus() == v:false
		call nexus#utils#msg("Error", "Cannot be executed due to a special buffer.")
		return
	endif

	call s:open_window()

	call nexus#explorer#start(start_dir)
endfunction

"---------------------------------------------------------------
" nexus#oldfiles
"---------------------------------------------------------------
function! nexus#mru() abort
	if nexus#utils#is_nexus() == v:false
		call nexus#utils#msg("Error", "Cannot be executed due to a special buffer.")
		return
	endif

	call s:open_window()

	call nexus#mru#start()
endfunction

"---------------------------------------------------------------
" nexus#finder
"---------------------------------------------------------------
function! nexus#finder(...) abort
	if nexus#utils#is_nexus() == v:false
		call nexus#utils#msg("Error", "Cannot be executed due to a special buffer.")
		return
	endif

	if len(a:000) && !empty(a:000[0])
		let start_dir = nexus#utils#win_to_unix(a:000[0])
	else
		let d = fnamemodify(bufname(bufnr("%")), ':p:h')
		let start_dir = resolve(input("Start directory: ", d, "dir"))
	endif

	if empty(start_dir) || !isdirectory(start_dir)
		call nexus#utils#msg("Error", printf("Could not set the starting directory. (%s)", start_dir))
		return
	endif

	call s:open_window()

	call nexus#finder#start(substitute(start_dir, '[\/]$', '', ''))
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

