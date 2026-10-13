let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" bookmark manage function
"---------------------------------------------------------------
" init bookmark
function! s:bookmark_init() abort
	if !empty(get(b:, "B", "")) | return | endif
	let b:B = {}
	let b:B.bookmark_file	= (has('win32') ? $HOME.'\_' : $HOME.'/.') . 'nexus_bookmark' 
	let b:B.bookmarks		= filereadable(b:B.bookmark_file) ? readfile(b:B.bookmark_file) : []
	let b:B.modified		= 0
endfunction

" save bookmark
function! s:bookmark_save() abort
	if b:B.modified
		call writefile(b:B.bookmarks, b:B.bookmark_file)
		let b:B.modified = v:false
	endif
endfunction

" add bookmark
function! s:bookmark_add(item, index) abort
	let b:B.modified = v:true
	call insert(b:B.bookmarks, a:item, a:index)
endfunction

" remove bookmark
function! s:bookmark_remove(index) abort
	let b:B.modified = v:true
	return remove(b:B.bookmarks, a:index)
endfunction

" get bookmark
function! s:get_bookmark(index) abort
	return {  "path" : matchstr(b:B.bookmarks[a:index], '^[^\t]*'),
			\ "name" : matchstr(b:B.bookmarks[a:index], '\t\zs.*')}
endfunction

"---------------------------------------------------------------
" open_current
"---------------------------------------------------------------
function! s:open_current(open_cmd, close_and_open) abort
	" 1st line and separaotr are invalid
	if line('.') == 1 || getline(".")[0] !=# " "
		  return
	endif

	call s:bookmark_save()

	let bookmark = s:get_bookmark(line(".") - 2)
	if isdirectory(bookmark.path)
		call nexus#explorer#start(bookmark.path)
	else
		call nexus#utils#open(bookmark.path, a:open_cmd, a:close_and_open)
	endif
endfunction

"---------------------------------------------------------------
" category
"---------------------------------------------------------------
function! s:category() abort
	let [ret, name] = nexus#utils#safe_input("Separaotr name: ", "", "")
	if ret == v:false
		return
	endif

	let item = "&sep\t" . name
	call s:bookmark_add(item, line(".") - 1)

	setlocal modifiable
	call append(line("."), empty(name) ? "" : "- " . name)
	setlocal nomodifiable
endfunction

"---------------------------------------------------------------
" edit
"---------------------------------------------------------------
function! s:edit() abort
	if line('.') == 1
		return
	endif

	let lnum = line(".") - 2
	let bookmark = s:get_bookmark(lnum)

	if bookmark.path ==# "&sep"
		let [ret, new_name] = nexus#utils#safe_input('New name: ', bookmark.name, "")
		if ret == v:false
			call nexus#utils#msg("Normal", "Cancelled.")
			return
		endif
		let _ = s:bookmark_remove(lnum)
		call s:bookmark_add("&sep\t" . new_name, lnum)
		let item = empty(new_name) ? '' : '- ' . new_name

	else
		let [ret, new_path] = nexus#utils#safe_input('New path: ', bookmark.path, 'dir')
		if ret == v:false || !len(new_path)
			call nexus#utils#msg("Normal", "Cancelled.")
			return
		endif
		let new_path = substitute(new_path, '[/|\\]$', "", "")
		if !isdirectory(new_path) && !filereadable(new_path)
			call nexus#utils#msg("Error", "New path is not exists.")
			return
		endif

		let [ret, new_name] = nexus#utils#safe_input('New name: ', bookmark.name, "")
		if ret == v:false
			call nexus#utils#msg("Normal", "Cancelled.")
			return
		endif
		let _ = s:bookmark_remove(lnum)
		call s:bookmark_add(empty(new_name) ? new_path : (new_path . "\t" . new_name), lnum)
		let item = "  " . (empty(new_name) ? new_path : new_name)
	endif

	redraw | echo

	setlocal modifiable
	call setline(line("."), item)
	setlocal nomodifiable
endfunction

"---------------------------------------------------------------
" updown
"---------------------------------------------------------------
function! s:updown(updown) abort
	let lnum = line(".")
	let next = lnum + (a:updown == 'up' ? -1 : 1)
	if lnum == 1 || next < 2 || next > len(b:B.bookmarks) + 1
		return
	endif

	let item = s:bookmark_remove(lnum - 2)
	call s:bookmark_add(item, next - 2)

	setlocal modifiable
	let item = getline(".")
	del _
	call append(next - 1, item)
	call cursor([next, 1, 0, 1])
	setlocal nomodifiable
endfunction

"---------------------------------------------------------------
" remove
"---------------------------------------------------------------
function! s:remove() abort
	let lnum = line(".")
	if lnum == 1
		return
	endif

	if nexus#utils#get_char("Delete ? [y/n] ") != 'y'
		return
	endif

	let _ = s:bookmark_remove(lnum - 2)

	setlocal modifiable
	del _
	setlocal nomodifiable
endfunction

"---------------------------------------------------------------
" exit
"---------------------------------------------------------------
function! s:exit() abort
	call s:bookmark_save()
	call nexus#explorer#start(b:E.current_dir)
endfunction

"---------------------------------------------------------------
" set_highlight
"---------------------------------------------------------------
function! s:set_highlight() abort
	syntax clear
 	syn match BxplorerSeparator		'^-\ .*'
	syn match BxplorerCurrentDir	'^[^\ \->].*'
	hi! def link BxplorerSeparator	Label
	hi! def link BxplorerCurrentDir	Title
endfunction

"---------------------------------------------------------------
" set_keymap
"---------------------------------------------------------------
function! s:set_keymap() abort
	mapclear <buffer>
	nnoremap <buffer> <silent><nowait> <ESC> :<C-u>call <SID>exit()<CR>
	nnoremap <buffer> <silent> q     :<C-u>call <SID>exit()<CR>
	nnoremap <buffer> <silent> <CR>  :<C-u>call <SID>open_current('edit', 0)<CR>
	nnoremap <buffer> <silent> l     :<C-u>call <SID>open_current('edit', 0)<CR>
	nnoremap <buffer> <silent> L     :<C-u>call <SID>open_current('edit', 1)<CR>
	nnoremap <buffer> <silent> v     :<C-u>call <SID>open_current('vsplit', 0)<CR>
	nnoremap <buffer> <silent> s     :<C-u>call <SID>category()<CR>
	nnoremap <buffer> <silent> e     :<C-u>call <SID>edit()<CR>
	nnoremap <buffer> <silent> K     :<C-u>call <SID>updown('up')<CR>
	nnoremap <buffer> <silent> J     :<C-u>call <SID>updown('down')<CR>
	nnoremap <buffer> <silent> rm    :<C-u>call <SID>remove()<CR>
	nnoremap <buffer> <silent> <C-j> :<C-u>call nexus#utils#jump_cursor(1, "-")<CR>
	nnoremap <buffer> <silent> <C-k> :<C-u>call nexus#utils#jump_cursor(-1, "-")<CR>
endfunction

"---------------------------------------------------------------
" open_bookmark
"---------------------------------------------------------------
function! s:open_bookmark() abort
	let output = []
	for bookmark in b:B.bookmarks
		let b = split(bookmark, "\t")
		if b[0] == "&sep"
			call add(output, len(b) > 1 ? "- " . b[1] : "")
		else
			call add(output, "  " . b[len(b) > 1 ? 1 : 0])
		endif
	endfor

	setlocal modifiable
	silent! %delete _
	call setline(1, ["bookmarks"] + output)
	setlocal nomodifiable

	call cursor([2, 1, 0, 1])
endfunction

"---------------------------------------------------------------
" nexus#bookmark#add
"---------------------------------------------------------------
function! nexus#bookmark#add(item) abort
	if empty(a:item)
		return
	endif

	call s:bookmark_init()
	call s:bookmark_add(a:item, 0)
	call s:bookmark_save()

	call nexus#utils#msg("Normal", printf('Add "%s" to bookmark.', a:item))
endfunction

"---------------------------------------------------------------
" nexus#bookmark#start
"---------------------------------------------------------------
function! nexus#bookmark#start() abort
	call s:set_keymap()

	call s:set_highlight()

	call s:bookmark_init()

	call s:open_bookmark()
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

