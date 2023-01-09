# Ludum Dare 52: Harvest

A game about collecting wheat.

![](./screenshot2.png)

Life is harsh for the common bird, but you have nested right above a ripe patch of wheat! Wheat can be found all over the ground! Collect as much as you can and store it safely in your nest for the coming winter.

## Controls

### Ground
left/right - skip

up - jump

space - flap wings

### Air (while flapping)
left/right/up/down - movement

space - hover

### General

t - show fps

v - toggle vsync

## Love2d/Box2D
At the last minute I realized that the physics behaves different on different computers, most is the same, but some key mechanics are physics based and for some it might unfortunately be impossible/a lot easier.

### Version 1.1.0
Tweaked version which plays roughly as intended on my windows system, but is a bit easier on my Ubuntu laptop.

### Version 1.0.0
First version which plays as intended on my Ubuntu laptop but is almost unplayable on my windows machine.

## Running the game

### Windows
Download zip from the [release page](https://github.com/Tiseno/LD52/releases]) unzip and run the exe.

### Others
Install [love2d](https://love2d.org/) and download the `wheat.love` file from the [release page](https://github.com/Tiseno/LD52/releases).

Run with
```
love wheat.love
```

#### Tips (MINOR SPOILERS)
* You spend more energy while carrying a lot.
* If you do not need to be economical with your energy, holding down space all the time while flying is easiest.
* You spend less ambient energy while in the nest, but that time spent alive does not count in the final score.
* When skipping on the ground, tapping space makes you skip/hover fast over the ground.
* Max carry was the mechanic changed on the different platforms and was intended to be 62.


## Distribution
```
cd game/
zip -r ../love/wheat.love *
```

### Windows
```
cat ~/Downloads/love-11.4-win64/lovec.exe love/wheat.love > dist64/wheat64.exe
cp ~/Downloads/love-11.4-win64/SDL2.dll ~/Downloads/love-11.4-win64/OpenAL32.dll ~/Downloads/love-11.4-win64/license.txt ~/Downloads/love-11.4-win64/love.dll ~/Downloads/love-11.4-win64/lua51.dll ~/Downloads/love-11.4-win64/mpg123.dll ~/Downloads/love-11.4-win64/msvcp120.dll ~/Downloads/love-11.4-win64/msvcr120.dll dist64/
cd dist64/
zip -r ../wheat64-1.1.0.zip *
```


```
cat ~/Downloads/love-11.4-win32/lovec.exe love/wheat.love > dist32/wheat32.exe
cp ~/Downloads/love-11.4-win32/SDL2.dll ~/Downloads/love-11.4-win32/OpenAL32.dll ~/Downloads/love-11.4-win32/license.txt ~/Downloads/love-11.4-win32/love.dll ~/Downloads/love-11.4-win32/lua51.dll ~/Downloads/love-11.4-win32/mpg123.dll ~/Downloads/love-11.4-win32/msvcp120.dll ~/Downloads/love-11.4-win32/msvcr120.dll dist32/
cd dist32/
zip -r ../wheat32-1.1.0.zip *
```
