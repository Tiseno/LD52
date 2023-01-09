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
zip -r ../wheat64-0.4.1.zip *
```
