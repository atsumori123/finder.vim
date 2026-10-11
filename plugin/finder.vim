if exists('g:loaded_finder')
	finish
endif
let g:loaded_finder = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

command! -bar -nargs=? -complete=dir Finder call finder#start(<f-args>)

let &cpoptions = s:save_cpo
unlet s:save_cpo
