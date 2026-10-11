let s:save_cpo = &cpoptions
set cpoptions&vim

let s:finder_bufnr = -1
let s:exe_bufnr = -1

"---------------------------------------------------------------
" finder#get_exe_bufnr
"---------------------------------------------------------------
function! finder#get_exe_bufnr() abort
	return bufexists(s:exe_bufnr) ? s:exe_bufnr : -1
endfunction

"---------------------------------------------------------------
" open_window
"---------------------------------------------------------------
function! s:open_window() abort
	enew
	execute 'silent keepalt file --explorer--'
	setlocal modifiable
	setlocal filetype=finder
	setlocal buftype=nofile
	setlocal bufhidden=delete
	setlocal noswapfile
	setlocal nowrap
	setlocal cursorline
endfunction

"---------------------------------------------------------------
" finderfy#start
"---------------------------------------------------------------
function! finder#start(...) abort
	let start_dir = resolve(get(a:000, 0, getcwd()))
	if !isdirectory(start_dir)
	 	call finder#utils#msg("Error", printf("Directory %s doesn't exist.", start_dir))
	endif

	if &buftype != ''
		call finder#utils#msg("Error", "Cannot be executed due to a special buffer.")
		return
	endif

	if bufexists(s:finder_bufnr) == 0
		let s:exe_bufnr = bufnr("%")
		let s:finnrder_bufnr = s:open_window()
	endif

	call finder#explorer#start(start_dir)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
