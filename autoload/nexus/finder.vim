let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" finder manage function
"---------------------------------------------------------------
" init finder
function! s:finder_init(start_dir, force) abort
	if !empty(get(b:, "F", "")) && !a:force | return | endif
	let b:F = {}
	let b:F.start_dir	= a:start_dir
	let b:F.files		= s:get_recursive_files(a:start_dir, v:false)
	let b:F.matches		= copy(b:F.files)
	let b:F.old_cond	= ""
	let b:F.pos_list	= []
endfunction

" get files list
function! s:get_files(cond) abort
	if !((len(b:F.old_cond) <= len(a:cond)) && stridx(a:cond, b:F.old_cond, 0) == 0)
		let b:F.matches = copy(b:F.files)
	endif

	if len(a:cond)
		if exists('*matchfuzzy')
			let [b:F.matches, b:F.pos_list, _] = matchfuzzypos(b:F.matches, a:cond)
		else
			let cond = ""
			for v in split(a:cond, "|")
				let cond .= printf("%sv:val %s '%s'", (len(cond) ? " && " : ""), (v =~# '[A-Z]' ? '=~#' : '=~?'), escape(v, '.'))
			endfor
			call filter(b:F.matches, cond)
		endif
	endif

	let b:F.old_cond = a:cond

	return b:F.matches
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
	if line(".") < 5 | return | endif
	call clearmatches(win_getid())
	let file = trim(getline("."))
	let path = printf("%s/%s", s:get('start_dir'), s:escape_filename(file))
	call nexus#utils#open(path, "edit", 0)
endfunction

"---------------------------------------------------------------
" reload_files
"---------------------------------------------------------------
function! s:reload_files() abort
	let b:F.files = s:get_recursive_files(s:get('start_dir'), v:true)
	call nexus#finder#update("")
endfunction

"---------------------------------------------------------------
" change_cache
"---------------------------------------------------------------
function! s:change_cache(direction) abort
	let cache_files = map(split(glob(s:get_cashe_directory() . '*.txt'), "\n"), 'fnamemodify(v:val, ":t")')
	let cache_file = substitute(s:get('start_dir'), '\([\/]\|^\a\zs:\)', '%', 'g') . ".txt"

	let idx = index(cache_files, cache_file)
	if idx == -1
		let idx = 0
	else
		let idx += a:direction
		let idx = idx < 0 ? len(cache_files) - 1 : idx >= len(cache_files) ? 0 : idx
	endif

	let sep = nexus#utils#get_sep()
	let start_dir = fnamemodify(cache_files[idx], ':r')
	let start_dir = substitute(start_dir, '%%', ':' . sep, '')
	let start_dir = substitute(start_dir, '%', sep, 'g')

	call s:finder_init(start_dir, v:true)
	call nexus#finder#update("")
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
	nnoremap <buffer> <silent> <BS>  :call nexus#utils#update_debounce_timer("BS", "nexus#finder#update")<CR>
	nnoremap <buffer> <silent> <c-u> :call nexus#utils#update_debounce_timer("CLR", "nexus#finder#update")<CR>
	nnoremap <buffer> <silent> <c-c> :call nexus#utils#exit()<CR>
	nnoremap <buffer> <silent> <c-l> :call <SID>change_cache(1)<CR>
	nnoremap <buffer> <silent> <c-h> :call <SID>change_cache(-1)<CR>
	nnoremap <buffer> <silent> <F5>  :call <SID>reload_files()<CR>

	" 必要な文字を一括登録
	let keys = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.|"
	for i in range(0, len(keys) - 1)
		let k = escape(keys[i], '|')
		execute printf('nnoremap <buffer> <silent> <nowait> %s :call nexus#utils#update_debounce_timer("%s", "nexus#finder#update")<CR>', k, k)
	endfor
endfunction

"---------------------------------------------------------------
" set_highlight
"---------------------------------------------------------------
function! s:set_highlight() abort
	syntax clear
	syntax match NXInfo '^  ---.*'
	highlight default link NXInfo Comment
  	highlight NXMatch ctermfg=10 guifg=LimeGreen
endfunction

"---------------------------------------------------------------
" make_inf
"---------------------------------------------------------------
function! s:make_inf(len) abort
	let inf = printf(" [ %s : %d files ] ", s:get('start_dir'), a:len)
	let bar = repeat("-", (winwidth(0) - len(inf) - 8) / 2)
	return "  " . bar . inf . bar
endfunction

"---------------------------------------------------------------
" first_render
"---------------------------------------------------------------
function! s:first_render() abort
	let files = s:get_files("")

	setlocal modifiable
	silent! %delete _
	call setline(1, ["", "  FILES > ", "", s:make_inf(len(files))] + files[:99])
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
	return printf("%s/vimplugins/_data/nexus_finder/", $HOME)
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

"-------------------------------------------------------
" nexus#finder#update
"-------------------------------------------------------
function! nexus#finder#update(cond) abort
	let winid = win_getid()

	" ハイライトを全クリア
	call clearmatches(winid)

	" ファイルリストを取得
	let files = s:get_files(a:cond)

	" 表示最大数
	let max_items = winheight(0) - 5

	setlocal modifiable
	silent! %delete _
	call setline(1, ["", "  FILES > " . a:cond, "", s:make_inf(len(files))] + files[:max_items])
	setlocal nomodifiable

	call cursor([5, 1])

	" フィルタリングパターンをハイライト
	if len(a:cond)
		if exists('*matchfuzzy')
			let pos_group = []
			for i in range(0, min([len(b:F.matches)-1, max_items]))
				let text = b:F.matches[i]
				for char_idx in b:F.pos_list[i]
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
" nexus#finder#start
"---------------------------------------------------------------
function! nexus#finder#start(start_dir) abort
	call s:finder_init(a:start_dir, v:false)

	call s:set_keymap()

	call s:set_highlight()

	call nexus#utils#set_cursor_limit(v:true, 5)

	call s:first_render()

	call nexus#utils#stop_debounce_timer()
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

