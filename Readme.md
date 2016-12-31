Trying to get this shit to work on Windows and Unix

* [Unix CI](https://travis-ci.org/JoshCheek/childprocess_experiment)
* [Windows CI](https://ci.appveyor.com/project/JoshCheek/childprocess-experiment)

Seems the trick is that you can't call `stop` after calling `wait`,
so you need to do a whole song and dance to get around that.
The ChildProcess gem tends to go invalid on Windows via missing handles
and nil objects. So we also have to catch a NoMethodError.
