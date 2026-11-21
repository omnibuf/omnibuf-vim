" OmniBuf filetype and binary read/write hooks for *.obuf files
augroup omnibuf_ftdetect
  autocmd!
  autocmd BufReadCmd *.obuf call omnibuf#read(expand('<afile>:p'))
  autocmd FileReadCmd *.obuf call omnibuf#read_append(expand('<afile>:p'))
  autocmd BufNewFile *.obuf call omnibuf#new_file(expand('<afile>:p'))
  autocmd BufWriteCmd *.obuf call omnibuf#write(expand('<afile>:p'))
  autocmd FileWriteCmd *.obuf call omnibuf#write_range(expand('<afile>:p'), line("'["), line("']"))
augroup END
