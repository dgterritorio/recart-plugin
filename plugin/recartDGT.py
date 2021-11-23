# -*- coding: utf-8 -*-
"""
/***************************************************************************
 RecartDGT
                                 A QGIS plugin
 Convert cartography datasets
                             -------------------
        begin                : 2020-07-02
        copyright            : (C) 2020 by Geomaster
        email                : geral@geomaster.pt
        git sha              : $Format:%H$
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License version 2 as     *
 *   published by the Free Software Foundation.                            *
 *                                                                         *
 ***************************************************************************/
"""
import os.path

from PyQt5.QtCore import QSettings, QTranslator, qVersion, QCoreApplication
from PyQt5.QtGui import QIcon
from PyQt5.QtWidgets import QAction

from .main_dialog import MainDialog
from .convert_dialog import ConvertDialog
from .validation_dialog import ValidationDialog

# Initialize Qt resources from file resources.py
from .resources import *


class recartDGT:
    """QGIS Plugin Implementation."""

    def __init__(self, iface):
        """Constructor.

        :param iface: An interface instance that will be passed to this class
            which provides the hook by which you can manipulate the QGIS
            application at run time.
        :type iface: QgsInterface
        """
        # Save reference to the QGIS interface
        self.iface = iface
        # initialize plugin directory
        self.plugin_dir = os.path.dirname(__file__)
        # initialize locale
        locale = QSettings().value('locale/userLocale')[0:2]
        locale_path = os.path.join(
            self.plugin_dir,
            'i18n',
            'recartDGT{}.qm'.format(locale))

        if os.path.exists(locale_path):
            self.translator = QTranslator()
            self.translator.load(locale_path)

            if qVersion() > '4.3.3':
                QCoreApplication.installTranslator(self.translator)

        # Create the dialog (after translation) and keep reference
        self.dlg = MainDialog(self.iface)
        self.dlgC = ConvertDialog(self.iface)
        self.dlgV = ValidationDialog(self.iface)

        title = self.dlg.windowTitle()
        self.dlg.setWindowTitle(title)
        self.dlgC.setWindowTitle(title)
        self.dlgV.setWindowTitle(title)

        # Declare instance attributes
        self.actions = []
        self.menu = self.tr(u'&recartDGT')

    # noinspection PyMethodMayBeStatic
    def tr(self, message):
        """Get the translation for a string using Qt translation API.

        We implement this ourselves since we do not inherit QObject.

        :param message: String for translation.
        :type message: str, QString

        :returns: Translated version of message.
        :rtype: QString
        """
        # noinspection PyTypeChecker,PyArgumentList,PyCallByClass
        return QCoreApplication.translate('recartDGT', message)

    def initGui(self):
        """Create the menu entries inside the QGIS GUI."""
        icon_path = ':/plugins/recartDGT/export.svg'
        icon = QIcon(icon_path)
        action = QAction(icon, self.tr(u'CartTop para QGIS, GPKG, JSON e SHP'),
                         self.iface.mainWindow())
        action.triggered.connect(self.run)
        action.setEnabled(True)

        iconC = QIcon(':/plugins/recartDGT/convert.svg')
        actionC = QAction(iconC, self.tr(u'MNT (DGN/DWG) para CartTop'),
                          self.iface.mainWindow())
        actionC.triggered.connect(self.runC)
        actionC.setEnabled(True)

        iconV = QIcon(':/plugins/recartDGT/validate.svg')
        actionV = QAction(iconV, self.tr(u'Validar Regras CartTop'),
                          self.iface.mainWindow())
        actionV.triggered.connect(self.runV)
        actionV.setEnabled(True)

        self.iface.addPluginToMenu(self.menu, action)
        self.iface.addPluginToMenu(self.menu, actionV)
        self.iface.addPluginToMenu(self.menu, actionC)
        self.actions.append(action)
        self.actions.append(actionC)
        self.actions.append(actionV)

    def unload(self):
        """Removes the plugin menu item and icon from QGIS GUI."""
        for action in self.actions:
            self.iface.removePluginMenu(
                self.tr(u'&recartDGT'),
                action)

    def run(self):
        """Runs the dialog event loop"""
        self.dlg.open()

    def runC(self):
        """Runs the dialog event loop"""
        self.dlgC.open()

    def runV(self):
        """Runs the dialog event loop"""
        self.dlgV.open()
