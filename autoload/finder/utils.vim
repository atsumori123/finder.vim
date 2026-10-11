let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" メッセージ出力
"---------------------------------------------------------------
function! finder#utils#msg(hl, msg) abort
	redraw
	execute 'echohl ' . a:hl | echo a:msg | echohl None
endfunction

"---------------------------------------------------------------
" 1文字入力
"---------------------------------------------------------------
function! finder#utils#get_char(prompt) abort
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
function! finder#utils#safe_input(prompt, text, completion)
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
" finder#utils#jump_cursor
"---------------------------------------------------------------
function! finder#utils#jump_cursor(direction, target_char) abort
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

let &cpoptions = s:save_cpo
unlet s:save_cpo
