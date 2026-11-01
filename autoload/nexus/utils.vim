let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" nexus#utils#is_nexus
"---------------------------------------------------------------
function! nexus#utils#is_nexus() abort
	let winnr = bufwinnr("-nexus-")
	if winnr != -1
		exe winnr.'wincmd w'
		return v:true
	elseif &buftype == ''
		return v:true
	endif

	return v:false
endfunction

"---------------------------------------------------------------
" nexus#utils#win_to_unix
"---------------------------------------------------------------
function! nexus#utils#win_to_unix(path) abort
	" バックスラッシュをスラッシュに置換
	let path = tr(a:path, '\', '/')
  
	" 必要に応じて先頭のドライブ小文字化
"	return substitute(path, '^\([A-Z]\):', '\L/\1', '')
"	return substitute(path, '^\([A-Z]\)', '\L\1', '')
	return path
endfunction

"---------------------------------------------------------------
" nexus#utils#get_sep
"---------------------------------------------------------------
function! nexus#utils#get_sep() abort
	return  has('win32') || has('win64') ? '\' : '/'
endfunction

"---------------------------------------------------------------
" メッセージ出力
"---------------------------------------------------------------
function! nexus#utils#msg(hl, msg) abort
	redraw
	execute 'echohl ' . a:hl | echo a:msg | echohl None
endfunction

"---------------------------------------------------------------
" 1文字入力
"---------------------------------------------------------------
function! nexus#utils#get_char(prompt) abort
	echohl MoreMsg
	try
		echo a:prompt
		let char = call('getchar', a:000)
	catch /^Vim:Interrupt$/
		let char = 3 " <C-c>
	endtry
	echohl None
	redraw | echo ""

	if char == 27 || char == 3
		" ESC or <C-c> key pressed
		redraw | echo "Cancelled."
		return ''
	endif

	return type(char) == v:t_number ? nr2char(char) : char
endfunction

"---------------------------------------------------------------
" nexus#utils#input
"---------------------------------------------------------------
function! nexus#utils#input(prompt, ...)
	let text = get(a:000, 0, "")
	let completion = get(a:000, 1, "none")

	echohl MoreMsg
	let ret = completion == "none" ? input(a:prompt, text) : input(a:prompt, text, completion)
	echohl None

	return ret
endfunction

"---------------------------------------------------------------
" キャンセル判定付き入力
"---------------------------------------------------------------
function! nexus#utils#safe_input(prompt, text, completion)
	" 事前に現在の入力状態を保存する
	call inputsave()
  
	" input()の入力欄でESCが押されたら、特殊な文字列を入れてEnterを叩くマッピングを動的に定義
	cnoremap <silent><buffer> <Esc> <C-u>__CANCEL__<CR>

	let str = ""
	let is_cancelled = 0

	try
		" 入力プロンプトを表示
		if empty(a:completion)
			let str = input(a:prompt, a:text)
		else
			let str = input(a:prompt, a:text, a:completion)
		endif
	catch /^Vim:Interrupt$/
		" Esc や Ctrl-C が押された場合、このブロックに入ります
		let is_cancelled = 1
	finally
		" 定義した一時的なマッピングを削除する
		cunmap <buffer> <Esc>
		" 入力状態を元に戻す
		call inputrestore()
	endtry

	" キャンセル判定
	if is_cancelled || str == '__CANCEL__'
		redraw | echo "Cancelled."
		return [v:false, ""]
	endif

	return [v:true, str]
endfunction

"---------------------------------------------------------------
" nexus#utils#open
"---------------------------------------------------------------
function! nexus#utils#open(path, open_cmd, close_and_open) abort
	let bufnr = nexus#get_exe_bufnr()

	call nexus#utils#exit()

	let winnr = bufwinnr('^' . a:path . '$')
	if winnr != -1
		execute winnr . 'wincmd w'
	else
		execute printf('%s %s', a:open_cmd, fnameescape(a:path))
	endif

	if a:close_and_open
		if bufexists(bufnr) && bufnr("%") != bufnr
			if getbufinfo(bufnr)[0].changed
				call nexus#utils#msg("WarningMsg", printf("Unsaved changes in buffer %s.", bufnr))
			else
				execute 'bdelete! '.bufnr
			endif
		endif
	endif
endfunction

"---------------------------------------------------------------
" nexus#utils#jump_cursor
"---------------------------------------------------------------
function! nexus#utils#jump_cursor(direction, target_char) abort
	let lnum = line(".") + a:direction
	let len = line('$')
	let first_lnum = 2

	for i in range(1, len)
		let lnum = lnum > len ? first_lnum : lnum < first_lnum ? len : lnum
		if getline(lnum) =~ "^" . a:target_char
			call cursor([lnum, 1, 0, 1])
			break
		endif
		let lnum += a:direction
	endfor
endfunction

"---------------------------------------------------------------
" 通常バッファを表示しているウィンドウにスイッチ
"---------------------------------------------------------------
function! nexus#utils#switch_normal_window() abort
	" カレントウィンドウが通常バッファを表示しているか
	if getbufvar('%', '&buftype') ==# ''
		return 1
	endif

	" ウィンドウリストを作成
	let current_win	= winnr()
	let last_win	= winnr("#")
	let list		= last_win ? [last_win] : []
	for i in range(1, winnr('$'))
		if i != current_win && i != last_win
			call add(list, i)
		endif
	endfor

	" 特殊バッファを表示しているウィンドウは除外
	call filter(list, 'getbufvar(winbufnr(v:val), "&buftype") ==# ""')

	if len(list)
		silent! exe list[0] . 'wincmd w'
		return 1
	endif

	return 0
endfunction

let s:save_key = ""
let s:debounce_timer_id = 0
"---------------------------------------------------------------
" nexus#utils#update_debounce_timer 
"---------------------------------------------------------------
function! nexus#utils#update_debounce_timer(key, callback) abort
	if	   a:key == "BS"  | let s:save_key = s:save_key[:-2]
	elseif a:key == "CLR" | let s:save_key = ""
	else				  |	let s:save_key .= a:key
	endif

	" タイマーが動いていたら停止
	if s:debounce_timer_id != 0
		call timer_stop(s:debounce_timer_id)
	endif

	" 100ms 入力が止まったら実行
	let s:debounce_timer_id = timer_start(100, {-> function(a:callback)(s:save_key)})
endfunction

"---------------------------------------------------------------
" nexus#utils#stop_debounce_timer
"---------------------------------------------------------------
function! nexus#utils#stop_debounce_timer() abort
	if exists('s:debounce_timer_id') && s:debounce_timer_id
		call timer_stop(s:debounce_timer_id)
		let s:debounce_timer_id = 0
	endif
	let s:save_key = ""
endfunction

"---------------------------------------------------------------
" nexus#utils#set_cursor_limit
"---------------------------------------------------------------
function! nexus#utils#set_cursor_limit(on, limit) abort
	if a:on == v:true
		let b:nexus_cursor_limit = a:limit
		augroup nexus_cursor_limit
			autocmd!
			autocmd CursorMoved <buffer> if line(".") < b:nexus_cursor_limit | call cursor([b:nexus_cursor_limit, 1]) | endif
		augroup END
	else
		if exists("#nexus_cursor_limit#CursorMoved") != 0
			augroup nexus_cursor_limit
				autocmd!
			augroup END
		endif
	endif
endfunction

"---------------------------------------------------------------
" nexus#utils#exit
"---------------------------------------------------------------
function! nexus#utils#exit() abort
	call clearmatches(win_getid())

	let exe_bufnr = nexus#get_exe_bufnr()
	if exe_bufnr == bufnr("%")
		bdelete
	elseif bufexists(exe_bufnr)
		execute printf('buffer! %d', exe_bufnr)
	endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

