" tty-beautify minimal Neovim config — tuned for the TTY (16 colors).
" Installed to the user's ~/.config/nvim/init.vim (the original is backed up first). No plugins.

set number
set showcmd
set ruler
set laststatus=2

set hlsearch
set incsearch
set ignorecase
set smartcase

set expandtab
set shiftwidth=4
set softtabstop=4
set autoindent

set wildmenu
set mouse=a

" Neovim wants truecolor (termguicolors) by default, but the bare kernel console
" has only 16 colors, so turning it off is safer; re-enable with `set termguicolors`
" in a real terminal / fbterm if you want truecolor.
set notermguicolors
set background=dark

syntax on
filetype plugin indent on
