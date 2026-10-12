let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" mru manage function
"---------------------------------------------------------------
" init mru
function! s:mru_init() abort
	if !empty(get(b:, "M", "")) | return | endif
	let b:M = {}
	let b:M.mru			= map(copy(s:OLDFILES[:29]), '"  " . fnamemodify(v:val, ":t")."  (" . v:val . ")"')
	let b:M.mru_work	= copy(b:M.mru)
	let b:M.old_cond	= ""
endfunction

" get mru list
function! s:get_mru(cond) abort
	if !((len(b:M.old_cond) <= len(a:cond)) && stridx(a:cond, b:M.old_cond, 0) == 0)
		let b:M.mru_work = copy(b:M.mru)
	endif

	if len(a:cond)
		let cond = ""
		for v in split(a:cond, "|")
			let cond .= printf("%sv:val %s '%s'", (len(cond) ? " && " : ""), (v =~# '[A-Z]' ? '=~#' : '=~?'), escape(v, '.'))
		endfor
		call filter(b:M.mru_work, cond)
	endif

	let b:M.old_cond = a:cond

	return b:M.mru_work
endfunction

"---------------------------------------------------------------
" load_mru
"---------------------------------------------------------------
function! s:load_mru() abort
	if exists('s:OLDFILES')
		return
	endif

	let s:OLDFILES = []
	for f in v:oldfiles
		if len(s:OLDFILES) >= 50 | break | endif

		" Convert to full path filename. check readable
		let file = expand(f)
		if !filereadable(file) | continue | endif

		" Add to list
		let file = fnameescape(file)
		call add(s:OLDFILES, file)
	endfor
endfunction

"---------------------------------------------------------------
" open_current 
"---------------------------------------------------------------
function! s:open_current() abort
	call clearmatches(win_getid())

	let filepath = matchstr(getline("."), '(\zs.*\ze)')

	call nexus#utils#exit()

	let winnum = bufwinnr('^' . filepath . '$')
	if winnum != -1
		" ターゲットバッファを開いているウィンドウがある
		exe winnum . 'wincmd w'
	elseif nexus#utils#switch_normal_window() == 0
		" 通常バッファを表示しているウィンドウが無い
		call nexus#utils#msg("Error", "Can not open because normal window does not exits.")
	else
		" 上記以外
		exe "edit " filepath
	endif
endfunction

"-------------------------------------------------------
" update_mru
"-------------------------------------------------------
function! nexus#mru#update_mru(cond) abort
	let winid = win_getid()

	" ハイライトを全クリア
	call clearmatches(winid)

	" MRUリストを取得
	let mru = s:get_mru(a:cond)

	" タイトルとメニューを更新
	let num  = printf(" < %d files > ", len(mru))
	let bar  = repeat("-", (winwidth(0) - len(num) - 8) / 2)
	let sepa = "  " . bar . num . bar
	
	set modifiable
	silent! %delete _
	call setline(1, ["", "  MRU > " . a:cond, "", sepa] + mru)
	set nomodifiable

	call cursor([5, 1])

	" フィルタリングパターンをハイライト
	if len(a:cond)
		for v in split(a:cond, "|")
			call matchadd('Title', (v =~# '[A-Z]' ? '' : '\c') . v, 10, -1, {'window': winid})
		endfor
	endif
endfunction

"---------------------------------------------------------------
" set_keymap
"---------------------------------------------------------------
function! s:set_keymap() abort
	mapclear <buffer>
	nnoremap <buffer> <silent> <c-j> j
	nnoremap <buffer> <silent> <c-k> k
	nnoremap <buffer> <silent><nowait> <ESC> :<C-u>call nexus#utils#exit()<CR>
	nnoremap <buffer> <silent> <CR>  :call <SID>open_current()<CR>
	nnoremap <buffer> <silent> <BS>  :call nexus#utils#update_debounce_timer("BS", "nexus#mru#update_mru")<CR>
	nnoremap <buffer> <silent> <c-u> :call nexus#utils#update_debounce_timer("CLR", "nexus#mru#update_mru")<CR>
	nnoremap <buffer> <silent> <c-c> :call nexus#utils#exit()<CR>

	" 必要な文字を一括登録
	let keys = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.|"
	for i in range(0, len(keys) - 1)
		let k = escape(keys[i], '|')
		execute printf('nnoremap <buffer> <silent> <nowait> %s :call nexus#utils#update_debounce_timer("%s", "nexus#mru#update_mru")<CR>', k, k)
	endfor
endfunction

"---------------------------------------------------------------
" set_highlight
"---------------------------------------------------------------
function! s:set_highlight() abort
	syntax clear
	syntax match MFilename '^.\{-}\ze('
	highlight default link MFilename Identifier
endfunction

"---------------------------------------------------------------
" set_autocmd
"---------------------------------------------------------------
function! s:set_autocmd() abort
	if exists("#nexus_mru#CursorMoved") == 0
		augroup nexus_mru
			autocmd!
			autocmd CursorMoved <buffer> if line(".") < 4 | call cursor([4, 1]) | endif
		augroup END
	endif
endfunction

"---------------------------------------------------------------
" initial_render
"---------------------------------------------------------------
function! s:first_render() abort
	let mru  = s:get_mru("")
	let num  = printf(" < %d files > ", len(mru))
	let bar  = repeat("-", (winwidth(0) - len(num) - 8) / 2)
	let sepa = "  " . bar . num . bar

	setlocal modifiable
	silent! %delete _
	call setline(1, ["", "  MRU > ", "", sepa] + mru)
	setlocal nomodifiable

	call cursor([5, 1])
endfunction

"---------------------------------------------------------------
" nexus#mru#add
"---------------------------------------------------------------
function! nexus#mru#add(bufnr) abort
	if !exists('s:OLDFILES')
		call s:load_mru()
	endif

	" Get the full path to the filename
	let file = fnamemodify(bufname(a:bufnr + 0), ':p')

	" 以下に該当する場合は履歴に追加しない
	" プレビュー、ファイル名が空、特殊バッファ、リードオンリー
	if &previewwindow || empty(file) || !empty(&buftype) || !filereadable(file)
		return
	endif

	" 既に履歴に存在する場合は一旦削除する
	call filter(s:OLDFILES, 'v:val !=# file')

	" 履歴の先頭に追加
	call insert(s:OLDFILES, file, 0)

	" 履歴の数を上限に丸める
	let s:OLDFILES = s:OLDFILES[:50-1]
endfunction

"---------------------------------------------------------------
" nexus#mru#start
"---------------------------------------------------------------
function! nexus#mru#start() abort
	call s:set_keymap()

	call s:set_highlight()

	call s:set_autocmd()

	call s:load_mru()

	call s:mru_init()

	call s:first_render()

	call nexus#utils#stop_debounce_timer()
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
