# Ludum Dare 52: Harvest

![](./screenshot2.png)

## Distribution
```
cd game/
zip -r ../love/wheat.love *
```

### Creating windows exe
```
cat ~/Downloads/love-11.4-win32/love.exe love/wheat.love > dist/wheat.exe
cp ~/Downloads/love-11.4-win32/SDL2.dll ~/Downloads/love-11.4-win32/OpenAL32.dll ~/Downloads/love-11.4-win32/license.txt ~/Downloads/love-11.4-win32/love.dll ~/Downloads/love-11.4-win32/lua51.dll ~/Downloads/love-11.4-win32/mpg123.dll ~/Downloads/love-11.4-win32/msvcp120.dll ~/Downloads/love-11.4-win32/msvcr120.dll dist/
zip -r wheat.zip dist/
```
