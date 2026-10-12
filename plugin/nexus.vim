if exists('g:loaded_nexus')
	finish
endif
let g:loaded_nexus = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

command! -bar -nargs=? -complete=dir NXExplorer call nexus#explorer(<f-args>)
command! -bar -nargs=? -complete=dir NXFinder call nexus#finder(<f-args>)
command! -bar -nargs=0  NXMru call nexus#mru()

autocmd BufRead			* call nexus#mru#add(expand('<abuf>'))
autocmd BufNewFile		* call nexus#mru#add(expand('<abuf>'))
autocmd BufWritePost	* call nexus#mru#add(expand('<abuf>'))

let &cpoptions = s:save_cpo
unlet s:save_cpo

