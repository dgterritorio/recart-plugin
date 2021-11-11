## Developement

The following steps can be used to setup the project for testing and developing:

### Development dependencies

The following software is needed to develop and build the puglin
```
apt install qttools5-dev-tools
```

### Virtualenv

Setup your python environment
```
apt install python-virtualenv

virtualenv -p python3 env
source env/bin/activate
pip3 install psycopg2
pip3 install pyqt5
pip3 install unidecode
```

### Edit Qt dialogs

Use Qt designer (or Qt Creator) to edit the .ui files
```
designer -qt5 "<path to .ui file>"
```

### Preview Qt dialogs
You can run the following command in order to preview ui dialogs
```
pyuic5 -d -p "<path to .ui file>"
```

### Make and package

```
make compile
make zip
```

### Deploy

Deploy and test in your local QGIS 3 installation
```
make deploy
```
Open plugin manager in QGIS, then search for this plugin and enable it.
