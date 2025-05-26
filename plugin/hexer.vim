" hexer.vim - Plugin initialization
if exists('g:loaded_hexer')
  finish
endif
let g:loaded_hexer = 1

" Create commands
command! -nargs=? -range HexerFormat lua require('hexer').format_calldata(<f-args>)
command! -nargs=? -range HexerBytesToAscii lua require('hexer').bytes_to_ascii(<f-args>)
command! -nargs=? -range HexerDecode lua require('hexer').abi_decode(<f-args>)

" Cache management commands
command! -nargs=0 HexerCacheStats lua require('hexer.cache').stats() |> vim.inspect() |> print()
command! -nargs=0 HexerCacheClear lua require('hexer.cache').clear() | echo "Hexer cache cleared"
command! -nargs=0 HexerCacheSave lua require('hexer.cache').save() | echo "Hexer cache saved"

" Default keymaps (can be disabled by setting g:hexer_no_mappings = 1)
if !exists('g:hexer_no_mappings')
  " [H]exer [D]ecode - ABI decode calldata
  nnoremap <leader>hd <cmd>HexerDecode<cr>
  vnoremap <leader>hd <cmd>HexerDecode<cr>
  
  " [H]exer [F]ormat - Format calldata  
  nnoremap <leader>hf <cmd>HexerFormat<cr>
  vnoremap <leader>hf <cmd>HexerFormat<cr>
  
  " [H]exer [A]scii - Convert to ASCII
  nnoremap <leader>ha <cmd>HexerBytesToAscii<cr>
  vnoremap <leader>ha <cmd>HexerBytesToAscii<cr>
endif