echo Fixing defaults.vim not found bug ...
if [ ! -f /usr/share/vim/vim74/defaults.vim ]; then
    cd /usr/share/vim
    ln -s vim.rc defaults.vim
fi