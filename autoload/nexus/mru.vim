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
	let b:M.matches		= copy(b:M.mru)
	let b:M.old_cond	= ""
	let b:M.pos_list	= []
endfunction

" get mru list
function! s:get_mru(cond) abort
	if !((len(b:M.old_cond) <= len(a:cond)) && stridx(a:cond, b:M.old_cond, 0) == 0)
		let b:M.matches = copy(b:M.mru)
	endif

	if len(a:cond)
		if exists('*matchfuzzy')
			let [b:M.matches, b:M.pos_list, _] = matchfuzzypos(b:M.matches, a:cond)
		else
			let cond = ""
			for v in split(a:cond, "|")
				let cond .= printf("%sv:val %s '%s'", (len(cond) ? " && " : ""), (v =~# '[A-Z]' ? '=~#' : '=~?'), escape(v, '.'))
			endfor
			call filter(b:M.matches, cond)
		endif
	endif

	let b:M.old_cond = a:cond

	return b:M.matches
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
	if line(".") < 5 | return | endif
	call clearmatches(win_getid())
	let path = matchstr(getline("."), '(\zs.*\ze)')
	call nexus#utils#open(path, "edit", 0)
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
	nnoremap <buffer> <silent> <BS>  :call nexus#utils#update_debounce_timer("BS", "nexus#mru#update")<CR>
	nnoremap <buffer> <silent> <c-u> :call nexus#utils#update_debounce_timer("CLR", "nexus#mru#update")<CR>
	nnoremap <buffer> <silent> <c-c> :call nexus#utils#exit()<CR>

	" 必要な文字を一括登録
	let keys = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.|"
	for i in range(0, len(keys) - 1)
		let k = escape(keys[i], '|')
		execute printf('nnoremap <buffer> <silent> <nowait> %s :call nexus#utils#update_debounce_timer("%s", "nexus#mru#update")<CR>', k, k)
	endfor
endfunction

"---------------------------------------------------------------
" set_highlight
"---------------------------------------------------------------
function! s:set_highlight() abort
	syntax clear
	syntax match NXInfo '^  ---.*'
	syntax match NXFilename '^.\{-}\ze('
	highlight default link NXInfo Comment
	highlight default link NXFilename Identifier
  	highlight NXMatch ctermfg=10 guifg=LimeGreen
endfunction

"---------------------------------------------------------------
" make_inf
"---------------------------------------------------------------
function! s:make_inf(len) abort
	let inf = printf(" [ %d files ] ", a:len)
	let bar = repeat("-", (winwidth(0) - len(inf) - 8) / 2)
	return "  " . bar . inf . bar
endfunction

"---------------------------------------------------------------
" initial_render
"---------------------------------------------------------------
function! s:first_render() abort
	let mru  = s:get_mru("")

	setlocal modifiable
	silent! %delete _
	call setline(1, ["", "  MRU > ", "", s:make_inf(len(mru))] + mru)
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

"-------------------------------------------------------
" nexus#mru#update
"-------------------------------------------------------
function! nexus#mru#update(cond) abort
	let winid = win_getid()

	" ハイライトを全クリア
	call clearmatches(winid)

	" MRUリストを取得
	let mru = s:get_mru(a:cond)

	setlocal modifiable
	silent! %delete _
	call setline(1, ["", "  MRU > " . a:cond, "", s:make_inf(len(mru))] + mru)
	setlocal nomodifiable

	call cursor([5, 1])

	" フィルタリングパターンをハイライト
	if len(a:cond)
		if exists('*matchfuzzy')
			let pos_group = []
			for i in range(len(b:M.matches))
				let text = b:M.matches[i]
				for char_idx in b:M.pos_list[i]
					" 文字インデックス(0始まり)をバイトインデックス(1始まり)に変換
					call add(pos_group, [i + 5, (byteidx(text, char_idx) + 1), 1])
				endfor
			endfor
			if !empty(pos_group)
				call matchaddpos('NXMatch', pos_group)
			endif
		else
			for v in split(a:cond, "|")
				call matchadd('NXMatch', (v =~# '[A-Z]' ? '' : '\c') . v, 10, -1, {'window': winid})
			endfor
		endif
	endif
endfunction

"---------------------------------------------------------------
" nexus#mru#start
"---------------------------------------------------------------
function! nexus#mru#start() abort
	call s:set_keymap()

	call s:set_highlight()

	call nexus#utils#set_cursor_limit(v:true, 5)

	call s:load_mru()

	call s:mru_init()

	call s:first_render()

	call nexus#utils#stop_debounce_timer()
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
