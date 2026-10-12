let s:save_cpo = &cpoptions
set cpoptions&vim

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
	try
		echo a:prompt
		let char = call('getchar', a:000)
	catch /^Vim:Interrupt$/
		let char = 3 " <C-c>
	endtry
	redraw | echo ""

	if char == 27 || char == 3
		" ESC or <C-c> key pressed
		redraw | echo "Cancelled."
		return ''
	endif

	return type(char) == v:t_number ? nr2char(char) : char
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
" nexus#utils#exit
"---------------------------------------------------------------
function! nexus#utils#exit() abort
	call clearmatches(win_getid())

	let exe_bufnr = nexus#get_exe_bufnr()
	if exe_bufnr == bufnr("%") || !bufexists(exe_bufnr)
		bdelete
	else
		execute printf('buffer! %d', exe_bufnr)
	endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

