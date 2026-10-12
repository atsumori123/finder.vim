let s:save_cpo = &cpoptions
set cpoptions&vim

"---------------------------------------------------------------
" nexus#file#remove
"---------------------------------------------------------------
function! nexus#file#remove(src) abort
	if empty(a:src)
		return v:false
	endif

	let src_fname = fnamemodify(a:src, ':t')

	let yn = nexus#utils#get_char(printf("Delete %s ? [y/n] ", src_fname))
	if yn !=# 'y'
		call nexus#utils#msg("Normal", "Cancelled.")
		return v:false
	endif

	let opt = ''
	if isdirectory(a:src)
		if empty(readdir(a:src, 1))
			let opt = 'd'
		else
			let yn = nexus#utils#get_char("Directory is not empty. Force delete ? [y/n] ")
			if yn !=# 'y'
				call nexus#utils#msg("Normal", "Cancelled.")
				return v:false
			endif
			let opt = 'rf'
		endif
	endif

	if delete(a:src, opt) < 0
		call nexus#utils#msg("Normal", "Cannot delete. " . a:src)
		return v:false
	endif

	call nexus#utils#msg("Normal", "Deleted. " . src_fname)

	return v:true
endfunction

"---------------------------------------------------------------
" nexus#file#copy
"---------------------------------------------------------------
function! nexus#file#copy(src) abort
	if empty(a:src)
		return v:false
	endif

	let [src_dir, src_fname] = [fnamemodify(a:src, ':h'), fnamemodify(a:src, ':t')]

	" コピー先を指定
	let dst_dir = resolve(input("Copy to ", src_dir, 'dir'))
	if empty(dst_dir)
		call nexus#utils#msg("Normal", "Cancelled.")
		return v:false
	endif

	" コピー先のディレクトリが存在しない場合は中止
	if !isdirectory(dst_dir)
		call nexus#utils#msg("Error", "Destination is not exists.")
		return v:false
	endif

	" Make distination path
	let dst_fname = src_fname
	let dst = dst_dir . '/' . dst_fname
	echom "dst=".dst

	" コピー先に既に同名のファイルが存在する場合は中止
	while filereadable(dst) || (isdirectory(dst) && (a:src == dst))
		redraw
		let dst_fname = input("Destination already has the same file. Input new name: ", src_fname)
		if empty(dst_fname)
			call nexus#utils#msg("Normal", "Cancelled.")
			return v:false
		endif
		let dst = dst_dir . '/' . dst_fname
	endwhile

	" コピー先のディレクトリが書き込み不可の場合は中止
	if !filewritable(dst_dir)
		call nexus#utils#msg("Error", "Destination directory is readonly.")
		return v:false
	endif

	" Make distination path
	let dst = dst_dir . '/' . dst_fname

	" Copy
	if has('win32')
		let win_src = substitute(a:src, '/', '\\', 'g')
		let win_dst = substitute(dst, '/', '\\', 'g')
		if isdirectory(a:src)
			let command = 'cmd.exe /d /c xcopy /E /I ' . win_src . ' ' . win_dst . ' > nul'
		else
			let command = 'cmd.exe /d /c copy /Y /B ' . win_src . ' ' . win_dst . ' > nul'
		endif
	else
		let opt = isdirectory(a:src) ? '-r -p -r' : '-p -r'
		let command = 'cp ' . opt . ' -- ' . shellescape(a:src) . ' ' . shellescape(dst)
	endif

	if system(command) !=# '' || v:shell_error != 0
		call nexus#utils#msg("Error", "Copy failed" . fnamemodify(a:src, ':t'))
		return v:false
	endif

	call nexus#utils#msg("Normal", printf("Copyed. '%s' --> '%s'", src_fname, dst))

	return v:true
endfunction

"---------------------------------------------------------------
" nexus#file#move
"---------------------------------------------------------------
function! nexus#file#move(src) abort
	if empty(a:src)
		return v:false
	endif

	let [src_dir, src_fname] = [fnamemodify(a:src, ':h'), fnamemodify(a:src, ':t')]

	"移動先ディレクトリの入力
	let dst_dir = resolve(input("Move to ", src_dir, 'dir'))
	if empty(dst_dir)
		call nexus#utils#msg("Normal", "Cancelled.")
		return v:false
	endif

	"移動先が存在しないディレクトリの場合はエラーとする
	if !isdirectory(dst_dir)
		call nexus#utils#msg("Error", "Destination is not exists.")
		return v:false
	endif

	"移動先のフルパスを作成
	let dst = dst_dir . '/' . src_fname

	"移動先が選択項目が同じ場所の場合は新しい名前をつける
	if a:src == dst
	 	let dst_fname = input('New name: ', src_fname)
		if empty(dst_fname)
			call nexus#utils#msg("Normal", "Cancelled.")
			return v:false
		endif

		let dst = dst_dir . '/' . dst_fname
		if a:src == dst
			call nexus#utils#msg("Error", "Destination already has the same object.")
			return v:false
		endif
	endif

	"Move
	call rename(a:src, dst)

	echo printf("\rMoved. '%s' --> '%s'", src_fname, dst)

	return v:true
endfunction

"---------------------------------------------------------------
" nexus#file#mkdir
"---------------------------------------------------------------
function! nexus#file#mkdir(dir) abort
	let name = input('Create directory name: ')
	if empty(name)
		call nexus#utils#msg("Normal", "Cancelled.")
		return v:false
	endif

	"Input new directory name
	let path = resolve(a:dir . '/' . name)

	" コピー先に既に同名のファイルが存在する場合は中止
	if isdirectory(path)
		call nexus#utils#msg("Error", "Destination already has the same directory.")
		return v:false
	endif

	" コピー先のディレクトリが書き込み不可の場合は中止
	if !filewritable(fnamemodify(path, ':h'))
		call nexus#utils#msg("Error", "Destination directory is readonly.")
		return v:false
	endif

	" Make new directory
	call mkdir(path, '')

	echo 'Created. ' . name

	return v:true
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

