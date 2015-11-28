# Visual Grep
A grep graphical user interface written in D and GTK 3

###### Main Window
![Screenshot](http://www.gexperts.com/img/vgrep/main.png)

###### Find Dialog
![Screenshot](http://www.gexperts.com/img/vgrep/options.png)

### About

Visual Grep is a small utility application that provides grep capabilities in a GUI application. While the command line grep is powerful and useful for a variety of tasks, there are times when I prefer using a GUI to persistently hold the results and make them easy to browse. Thus this utility was born to scratch that itch.

The following features are currently available:

* Supports tabs for multiple searches
* Multi-threaded application, searches happen in the background
* Supports regular expressions as per the [D documentation](http://dlang.org/phobos/std_regex.html)

The application was written using GTK 3 and an effort was made to conform to Gnome Human Interface Guidelines (HIG). As a result, it does use CSD (i.e. the GTK HeaderBar) and no allowance has been made for other Desktop Environments (xfce, unity, kde, etc) at this time so your mileage may vary. Consideration for other environments may be given if demand warrants it.

At this point in time the application should be considered early alpha and has only been tested under Arch Linux using GTK 3.1.8.

### Dependencies

Visual Grep requires the following libraries to be installed in order to run:
* GTK 3.1.6 or later

### Todo Items

Since this is an early alpha release, there are a number of features which have not yet been developed including:

* Save recent searches
* Support regex for file matching
* Command line parameters
* Support sorting in result and match lists

Additional feature requests are gladly accepted

### Building

Visual Grep is written in D and GTK 3 using the gtkd framework. This project uses dub to manage the build process including fetching the dependencies, thus there is no need to install dependencies manually. The only thing you need to install to build the application is the D tools (DMD and Phobos) along with dub itself.

Once you have those installed, building the application is a one line command as follows:

```
dub build --build=release
```
#### Build Dependencies

Visual Grep depends on the following libraries as defined in dub.json:
* [gtkd](http://gtkd.org/) >= 3.1.4
* [sdlang-d](https://github.com/Abscissa/SDLang-D/blob/master/HOWTO.md) >= 0.9.3

### Installation

Visual Grep can be installed on arch by using the *visual-grep* package in AUR.

For other distros, no installation packages are available at this time. A compiled binary can be downloaded from the releases.
