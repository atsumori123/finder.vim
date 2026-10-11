let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" explorer manage function
"---------------------------------------------------------------
" initialize explorer
function! s:explorer_init(start_dir) abort
	let b:E = {}
	let b:E.current_dir	= a:start_dir
	let b:E.last_dir	= ""
	let b:E.show_hidden	= v:false
	let b:E.items		= []
endfunction

" move to parent directory
function! s:explorer_to_parent() abort
	let b:E.last_dir	= b:E.current_dir
	let b:E.current_dir	= fnamemodify(b:E.last_dir, ':h')
	let b:E.items		= s:get_items_from_dir(b:E.current_dir, b:E.show_hidden)
endfunction

" move to child directory
function! s:explorer_to_child(dir) abort
	let b:E.last_dir	= b:E.current_dir
	let b:E.current_dir	= a:dir
	let b:E.items		= s:get_items_from_dir(a:dir, b:E.show_hidden)
endfunction

" set toggle hidden
function! s:explorer_toggle_hidden() abort
	let b:E.show_hidden	= !b:E.show_hidden
	let b:E.items		= s:get_items_from_dir(b:E.current_dir, b:E.show_hidden)
endfunction

"get items from dir
function! s:explorer_get_items(dir) abort
	let b:E.items		= s:get_items_from_dir(a:dir, b:E.show_hidden)
endfunction

" get explorer param
function! s:get(key) abort
	return b:E[a:key]
endfunction

"---------------------------------------------------------------
" name
"---------------------------------------------------------------
function! s:name(base, v) abort
	let type = a:v['type']
	if type ==# 'link' || type ==# 'junction'
		if isdirectory(resolve(a:base .. a:v['name']))
			let type = 'dir'
		endif
	elseif type ==# 'linkd'
		let type = 'dir'
	endif
	return a:v['name'] .. (type ==# 'dir' ? '/' : '')
endfunction

"---------------------------------------------------------------
" compare
"---------------------------------------------------------------
function! s:compare(r1, r2) abort
	let r1_is_dir = a:r1[-1:] ==# '/' ? 1 : 0
	let r2_is_dir = a:r2[-1:] ==# '/' ? 1 : 0
	if r1_is_dir != r2_is_dir
		" Show directory in first
		return r1_is_dir ? -1 : +1
	endif
	return char2nr(a:r1) - char2nr(a:r2)
endfunction

"---------------------------------------------------------------
" render
"---------------------------------------------------------------
function! s:render_items() abort
	let items = s:get('items')
	let lines = empty(items) ? ['  (no items)'] : map(copy(items), 'printf("  %s", v:val)')

	let current_dir = s:get('current_dir')
	let dellen = strlen(current_dir) - (&columns - 10)
	if dellen > 0
		let current_dir = "..".current_dir[dellen:]
	endif

	setlocal modifiable
	silent! %delete _
	call setline(1, [current_dir] + lines)
	setlocal nomodifiable

	call s:restore_cursor()
endfunction

"---------------------------------------------------------------
" get_items_from_dir
"---------------------------------------------------------------
function! s:get_items_from_dir(dir, show_hidden) abort
	if exists('*readdirex')
		let items = map(readdirex(a:dir, '1', {'sort': 'none'}), {_, v -> s:name(a:dir, v)})
	else
		let items = map(readdir(a:dir, '1'), {_, v -> s:name(a:dir, {'type': getftype(a:dir .. '/' .. v), 'name': v})})
	endif

	if a:show_hidden
		call filter(items, 'v:val =~# "^[^.]"')
	endif

	return sort(items, function('s:compare'))
endfunction

"---------------------------------------------------------------
" get_cursor_item
"---------------------------------------------------------------
function! s:get_cursor_item() abort
	let item = get(s:get("items"), line(".") - 2, "")
	let item = substitute(item, "\[\\/\]$", "", "")

	return empty(item) ? "" : s:get('current_dir') . "/" . item
endfunction

"---------------------------------------------------------------
" restore_cursor
"---------------------------------------------------------------
function! s:restore_cursor() abort
	let last_dir = s:get("last_dir")
	let last_dir = last_dir ==# "/" ? "/" : split(last_dir, "\[\\/\]")[-1]."/"
	let idx = index(s:get('items'), last_dir)
	let lnum = idx == -1 ? 2 : idx + 2
	call cursor([lnum, 1, 0, 1])
endfunction

"---------------------------------------------------------------
" proposed_cursor
"---------------------------------------------------------------
function! s:proposed_cursor() abort
	let char = nr2char(getchar())
	let match_char   = empty(char) ? ">" : escape(char, '^$.*[]/~\')
	let replace_char = empty(char) ? " " : ">"

	setlocal modifiable

	let min_abs = 9999
	for i in range(2, line("$") + 1)
		let line = getline(i)

		if line =~ "^. " . match_char
			call setline(i, replace_char . line[1:])
			let abs = abs(line(".") - i)
			if min_abs > abs
				let min_abs = abs
				let cursor_pos = i
			endif
		elseif line =~ "^>"
			call setline(i, " " . line[1:])
		endif
	endfor

	setlocal nomodifiable

	if char != "" && min_abs != 9999
		call cursor([cursor_pos, 1, 0, 1])
	endif
endfunction

"---------------------------------------------------------------
" open_parent
"---------------------------------------------------------------
function! s:open_parent() abort
	call s:explorer_to_parent()
	call s:render_items()
endfunction

"---------------------------------------------------------------
" open_current
"---------------------------------------------------------------
function! s:open_current(open_cmd, close_and_open) abort
	if line('.') == 1
		return
	endif

	let item = s:get_cursor_item()
	if empty(item)
		return
	endif

	if isdirectory(item)
		call s:explorer_to_child(item)
		call s:render_items()
	else
		call finder#explorer#open(item, a:open_cmd, a:close_and_open)
	endif
endfunction

"---------------------------------------------------------------
" toggle_hidden
"---------------------------------------------------------------
function! s:toggle_hidden() abort
	call s:explorer_toggle_hidden()
	call s:render_items()
endfunction

"---------------------------------------------------------------
" file_action
"---------------------------------------------------------------
function! s:file_action(action) abort
	let ret = v:false

	if     a:action ==# "rm" | let ret = finder#file#remove(s:get_cursor_item())
	elseif a:action ==# "cp" | let ret = finder#file#copy(s:get_cursor_item())
	elseif a:action ==# "mv" | let ret = finder#file#move(s:get_cursor_item())
	elseif a:action ==# "mk" | let ret = finder#file#mkdir(s:get("current_dir"))
	endif

	if ret == v:true
		call s:explorer_get_items(s:get('current_dir'))
		call s:render_items()
	endif
endfunction

"---------------------------------------------------------------
" exit
"---------------------------------------------------------------
function! s:exit() abort
	let exe_bufnr = finder#get_exe_bufnr()
	if exe_bufnr == bufnr("%") || !bufexists(exe_bufnr)
		bdelete
	else
		execute printf('buffer! %d', exe_bufnr)
	endif
endfunction

"---------------------------------------------------------------
" set_keymap
"---------------------------------------------------------------
function! s:set_keymap() abort
	mapclear <buffer>
	nnoremap <buffer> <silent><nowait> <ESC> :<C-u>call <SID>exit()<CR>
	nnoremap <buffer> <silent> q     :<C-u>call <SID>exit()<CR>
	nnoremap <buffer> <silent> <CR>  :<C-u>call <SID>open_current('edit', v:false)<CR>
	nnoremap <buffer> <silent> l     :<C-u>call <SID>open_current('edit', v:false)<CR>
	nnoremap <buffer> <silent> L     :<C-u>call <SID>open_current('edit', v:true)<CR>
	nnoremap <buffer> <silent> v     :<C-u>call <SID>open_current('vsplit', v:false)<CR>
	nnoremap <buffer> <silent> h     :<C-u>call <SID>open_parent()<CR>
	nnoremap <buffer> <silent> .     :<C-u>call <SID>toggle_hidden()<CR>
	nnoremap <buffer> <silent> s     :<C-u>call <SID>proposed_cursor()<CR>
	nnoremap <buffer> <silent> <C-j> :<C-u>call finder#utils#jump_cursor(1, ">")<CR>
	nnoremap <buffer> <silent> <C-k> :<C-u>call finder#utils#jump_cursor(-1, ">")<CR>
	nnoremap <buffer> <silent> b     :<C-u>call finder#bookmark#start()<CR>
	nnoremap <buffer> <silent> a     :<C-u>call finder#bookmark#add(<SID>get_cursor_item())<CR>
	nnoremap <buffer> <silent> rm    :<C-u>call <SID>file_action("rm")<CR>
	nnoremap <buffer> <silent> cp    :<C-u>call <SID>file_action("cp")<CR>
	nnoremap <buffer> <silent> mv    :<C-u>call <SID>file_action("mv")<CR>
	nnoremap <buffer> <silent> mk    :<C-u>call <SID>file_action("mk")<CR>
endfunction

"---------------------------------------------------------------
" set_highlight
"---------------------------------------------------------------
function! s:set_highlight() abort
	syntax clear
	syntax match ExplorerDirectory		'^  .\+/$'
	syntax match ExplorerHidden			'^  \..\+$'
	syntax match ExplorerNoItems		'^  (no items)$'
	syntax match ExplorerMatch			'^>.*'
	syntax match ExplorerCurrentDir		'^[^\ \->].*'
	highlight! default link ExplorerDirectory	Directory
	highlight! default link ExplorerHidden		Comment
	highlight! default link ExplorerNoItems		Comment
	highlight! default link ExplorerMatch		Special
	highlight! default link ExplorerCurrentDir	Title
endfunction

"---------------------------------------------------------------
" finder#explorer#open
"---------------------------------------------------------------
function! finder#explorer#open(path, open_cmd, close_and_open) abort
	call s:exit()

	" ファイルがバッファにロード済みか
	let winnr = bufwinnr('^' . a:path . '$')
	if winnr != -1
		" ロードしているバッファにスイッチ
		execute winnr . 'wincmd w'
	else
		" 新しくバッファにロードする
		execute printf('%s %s', a:open_cmd, fnameescape(a:path))
	endif

	if a:close_and_open
		let bufnr = s:get('finder_exe_bufnr')
		if bufexists(bufnr) && bufnr("%") != bufnr
			if getbufinfo(bufnr)[0].changed
				call finder#utils#msg("WarningMsg", printf("Unsaved changes in buffer %s.", bufnr))
			else
				execute 'bdelete! '.bufnr
			endif
		endif
	endif
endfunction

"---------------------------------------------------------------
" finder#explorer#start
"---------------------------------------------------------------
function! finder#explorer#start(start_dir) abort
	call s:set_keymap()

	call s:set_highlight()

	call s:explorer_init(a:start_dir)

	call s:explorer_to_child(a:start_dir)

	call s:render_items()
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
