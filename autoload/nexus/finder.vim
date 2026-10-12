let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" finder manage function
"---------------------------------------------------------------
" init finder
function! s:finder_init(start_dir) abort
	if !empty(get(b:, "F", "")) | return | endif
	let b:F = {}
	let b:F.start_dir	= a:start_dir
	let b:F.files		= s:get_recursive_files(a:start_dir, 0)
	let b:F.files_work	= copy(b:F.files)
	let b:F.old_cond	= ""
endfunction

" get files list
function! s:get_files(cond) abort
	if !((len(b:F.old_cond) <= len(a:cond)) && stridx(a:cond, b:F.old_cond, 0) == 0)
		let b:F.files_work = copy(b:F.files)
	endif

	if len(a:cond)
		let cond = ""
		for v in split(a:cond, "|")
			let cond .= printf("%sv:val %s '%s'", (len(cond) ? " && " : ""), (v =~# '[A-Z]' ? '=~#' : '=~?'), escape(v, '.'))
		endfor
		call filter(b:F.files_work, cond)
	endif

	let b:F.old_cond = a:cond

	return b:F.files_work
endfunction

" get finder param
function! s:get(key) abort
	return b:F[a:key]
endfunction

"---------------------------------------------------------------
" escape filename
"---------------------------------------------------------------
function! s:escape_filename(file) abort
	if exists("*fnameescape")
		return fnameescape(a:file)
	else
		let esc_filename_chars = ' *?[{`$%#"|!<>();&' . "'\t\n"
		return escape(a:file, esc_filename_chars)
	endif
endfunction

"---------------------------------------------------------------
" open_current 
"---------------------------------------------------------------
function! s:open_current() abort
	call clearmatches(win_getid())

	let file = trim(getline("."))
	let filepath = printf("%s/%s", s:get('start_dir'), s:escape_filename(file))

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
" nexus#finder#update_files
"-------------------------------------------------------
function! nexus#finder#update_files(cond) abort
	let winid = win_getid()

	" ハイライトを全クリア
	call clearmatches(winid)

	" ファイルリストを取得
	let files = s:get_files(a:cond)

	" タイトルとメニューを更新
	let num  = printf(" < %d files > ", len(files))
	let bar  = repeat("-", (winwidth(0) - len(num) - 8) / 2)
	let sepa = "  " . bar . num . bar

	set modifiable
	silent! %delete _
	call setline(1, ["", "  FINDER > " . a:cond, "", sepa] + files)
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
	nnoremap <buffer> <silent> <BS>  :call nexus#utils#update_debounce_timer("BS", "nexus#finder#update_files")<CR>
	nnoremap <buffer> <silent> <c-u> :call nexus#utils#update_debounce_timer("CLR", "nexus#finder#update_files")<CR>
	nnoremap <buffer> <silent> <c-c> :call nexus#utils#exit()<CR>

	" 必要な文字を一括登録
	let keys = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.|"
	for i in range(0, len(keys) - 1)
		let k = escape(keys[i], '|')
		execute printf('nnoremap <buffer> <silent> <nowait> %s :call nexus#utils#update_debounce_timer("%s", "nexus#finder#update_files")<CR>', k, k)
	endfor
endfunction

"---------------------------------------------------------------
" set_autocmd
"---------------------------------------------------------------
function! s:set_autocmd() abort
	if exists("#nexus_finder#CursorMoved") == 0
		augroup nexus_filefinde
			autocmd!
			autocmd CursorMoved <buffer> if line(".") < 4 | call cursor([4, 1]) | endif
		augroup END
	endif
endfunction

"---------------------------------------------------------------
" first_render
"---------------------------------------------------------------
function! s:first_render() abort
	let files = s:get_files("")
	let num   = printf(" < %d files > ", len(files))
	let bar   = repeat("-", (winwidth(0) - len(num) - 4) / 2)
	let sepa  = "  " . bar . num . bar

	setlocal modifiable
	silent! %delete _
	call setline(1, ["", "  FILES > ", "", sepa] + files)
	setlocal nomodifiable

	call cursor([5, 1])
endfunction

"---------------------------------------------------------------
" 指定ディレクトリ以下のファイル一覧を取得
"---------------------------------------------------------------
function! s:get_file_list_from_directory(start_dir) abort
	let ignore_dirs = [
		\ '\.hg',
		\ '\.svn',
		\ '\.cdv',
		\ 'obj',
		\ 'CVS',
		\ 'SCCS',
		\ '_build',
		\ ]

	let ignore_files = [
		\ '#.+#$',
		\ '[._].*\.swp$',
		\ 'core\.\d+$',
		\ '\.exe$',
		\ '\.so$',
		\ '\.bin$',
		\ '\.a$',
		\ '\.o$',
		\ '\.bak$',
		\ '\.png$',
		\ '\.jpg$',
		\ '\.gif$',
		\ '\.zip$',
		\ '\.rar$',
		\ '\.tar\.gz$',
		\ ]

	call nexus#utils#msg("Search", ">>> file searching (" . a:start_dir . ")>>>")

	execute "lcd " a:start_dir
	" vimのglobpathで検索
	let list = split(globpath(a:start_dir, '**/*', 1), "\n") + split(globpath(a:start_dir, '**/.*', 1), "\n")
	" ディレクトリを除外してファイルのみにする
	call filter(list, '!isdirectory(v:val)')
	" 相対パスにする
	call map(list, 'fnamemodify(v:val, ":.")')
	execute "lcd -"

	" 除外ディレクトリを正規表現で結合してフィルタリング
	let ignore_pattern = join(ignore_dirs, '/' . '\|')
	call filter(list, 'v:val !~# ignore_pattern')

	" 除外ファイルでフィルタリング
	let ignore_pattern = join(ignore_files, '\|')
	call filter(list, 'v:val !~# ignore_pattern')

	redraw | echo ""

	return list
endfunction

"---------------------------------------------------------------
" キャッシュディレクトリの取得
"---------------------------------------------------------------
function! s:get_cashe_directory() abort
	if has('unix') || has('macuni')
		return $HOME . '/nexus_finder/'
	elseif has('win32') && $USERPROFILE != ''
		return $USERPROFILE . '\nexus_finder\'
	else
		return $VIM . '/nexus_finder/'
	endif
endfunction

"---------------------------------------------------------------
" ファイル一覧の取得
"---------------------------------------------------------------
function! s:get_recursive_files(start_dir, force) abort
	" 読み込みキャッシュファイルのパス
	let cache_dir = s:get_cashe_directory()
	let cache_file = cache_dir . substitute(a:start_dir, '\([\/]\|^\a\zs:\)', '%', 'g').'.txt'

	if !filereadable(cache_file) || a:force
		" 指定ディレクトリ以下を再帰的に検索してファイル一覧を作成する
		let files = s:get_file_list_from_directory(a:start_dir)

		" キャッシュディレクトリに保存。キャッシュディレクトリが無い場合は作成する
		if exists('*mkdir') && !isdirectory(cache_dir)
			silent! call mkdir(cache_dir, 'p')
		endif
		silent! call writefile(files, cache_file)
	else
		" キャッシュファイルから読み込む
		let files = readfile(cache_file)
	endif

	return map(files, '"  " . v:val')
endfunction

"---------------------------------------------------------------
" nexus#finder#start
"---------------------------------------------------------------
function! nexus#finder#start(start_dir) abort
	call s:finder_init(a:start_dir)

	call s:set_keymap()

	call s:set_autocmd()

	call s:first_render()

	call nexus#utils#stop_debounce_timer()
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

