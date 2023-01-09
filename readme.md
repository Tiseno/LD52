# Ludum Dare 52: Harvest

![](./screenshot2.png)

## Distribution
```
cd game/
zip -r ../love/wheat.love *
```

### Creating windows executable
```
cat ~/Downloads/love-11.4-win64/lovec.exe love/wheat.love > dist/wheat64.exe
cp ~/Downloads/love-11.4-win64/SDL2.dll ~/Downloads/love-11.4-win64/OpenAL32.dll ~/Downloads/love-11.4-win64/license.txt ~/Downloads/love-11.4-win64/love.dll ~/Downloads/love-11.4-win64/lua51.dll ~/Downloads/love-11.4-win64/mpg123.dll ~/Downloads/love-11.4-win64/msvcp120.dll ~/Downloads/love-11.4-win64/msvcr120.dll dist/
cd dist/
zip -r ../wheat64-1.0.0.zip *
```


```
cat ~/Downloads/love-11.4-win32/lovec.exe love/wheat.love > dist/wheat32.exe
cp ~/Downloads/love-11.4-win32/SDL2.dll ~/Downloads/love-11.4-win32/OpenAL32.dll ~/Downloads/love-11.4-win32/license.txt ~/Downloads/love-11.4-win32/love.dll ~/Downloads/love-11.4-win32/lua51.dll ~/Downloads/love-11.4-win32/mpg123.dll ~/Downloads/love-11.4-win32/msvcp120.dll ~/Downloads/love-11.4-win32/msvcr120.dll dist32/
cd dist32/
zip -r ../wheat32-1.0.0.zip *
```
