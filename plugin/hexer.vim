" hexer.vim - Plugin initialization
if exists('g:loaded_hexer')
  finish
endif
let g:loaded_hexer = 1

" Create commands
command! -nargs=? -range HexerFormat lua require('hexer').format_calldata(<f-args>)
command! -nargs=? -range HexerBytesToAscii lua require('hexer').bytes_to_ascii(<f-args>)
command! -nargs=? -range HexerDecode lua require('hexer').abi_decode(<f-args>)

" Deprecated commands for backward compatibility
command! -nargs=0 HexerFormatCalldata lua require('hexer').format_calldata()
command! -nargs=0 HexerConvertBytesToAscii lua require('hexer').bytes_to_ascii()

" Default keymaps (can be disabled by setting g:hexer_no_mappings = 1)
if !exists('g:hexer_no_mappings')
  nnoremap <leader>ha <cmd>HexerDecode<cr>
  vnoremap <leader>ha <cmd>HexerDecode<cr>
endif