# Visual Grep
A grep graphical user interface written in D and GTK 3

###### Main Window
![Screenshot](http://www.gexperts.com/img/vgrep/main.png)

###### Find Dialog
![Screenshot](http://www.gexperts.com/img/vgrep/options.png)

### About

Visual Grep is a small utility application that provides grep capabilities in a GUI application. While the command line grep is powerful and useful for a variety of tasks, there are times when I prefer using a GUI to persistently hold the results and make them easy to browse. Thus this utility was born to scratch that itch.

The application was written using GTK 3 and an effort was made to conform to Gnome Human Interface Guidelines (HIG). As a result, it does use CSD (i.e. the GTK HeaderBar) and no allowance has been made for other Desktop Environments (xfce, unity, kde, etc) at this time so your mileage may vary. Consideration for other environments may be given if demand warrants it.

At this point in time the application should be considered early alpha and has only been tested under Arch Linux using GTK 3.1.8.

### Dependencies

Visual Grep requires the following libraries to be installed in order to run:
* GTK 3.1.6 or later

### Building

Visual Grep is written in D and GTK 3 using the gtkd framework. This project uses dub to manage the build process including fetching the dependencies, thus there is no need to install dependencies manually. The only thing you need to install to build the application is the D tools (DMD and Phobos) along with dub itself.

Once you have those installed, building the application is a one line command as follows:

```
dub build --build=release
```
#### Build Dependencies

Visual Grep depends on the following libraries as defined in dub.json:
* gtkd >= 3.1.4
* sdlang-d >= 0.9.3

### Installation

No installation packages are available at this time, I hope to create Arch packages in the next couple of weeks.
