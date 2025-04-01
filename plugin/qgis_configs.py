# -*- coding: utf-8 -*-
"""
/***************************************************************************
 RecartDGT
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
from qgis.PyQt.QtCore import QSettings
from qgis.PyQt.QtWidgets import QInputDialog, QMessageBox, QLineEdit
from qgis.core import QgsApplication, QgsAuthMethodConfig

def listDataSources():
    # dataSources = []
    settings = QSettings()

    settings.beginGroup("/PostgreSQL/connections")
    keys = settings.childGroups()
    # for key in keys:
    #     dataSources[key] = key
    # settings.endGroup()

    return keys


def getConnString(parent, conName):
    settings = QSettings()
    settings.beginGroup(u"/PostgreSQL/connections/" + conName)

    if not settings.contains("database"):
        QMessageBox.critical(
            parent, "Error", "Unable to connect: there is no defined database connection \"%s\"." % conName)
        return

    service, host, db, user, passw, authcfg = map(lambda x: settings.value(
        x), ["service", "host", "database", "username", "password", "authcfg"])

    if service:
        return ('service=%s') % (service)

    if authcfg:
        authMgr = QgsApplication.authManager()
        newAU = QgsAuthMethodConfig()
        authMgr.loadAuthenticationConfig(authcfg, newAU, True)
        cMap = newAU.configMap()
        if not user and cMap['username']:
            user = cMap['username']
        if not passw and cMap['password']:
            passw = cMap['password']      

    port = int(settings.value("port"))

    if not user:
        (user, ok) = QInputDialog.getText(parent, "Enter user name",
                                          "Enter user name for connection \"%s\":" % conName, QLineEdit.Normal)
        if not ok:
            return

    if not passw:
        (passw, ok) = QInputDialog.getText(parent, "Enter password",
                                           "Enter password for connection \"%s\":" % conName, QLineEdit.Password)
        if not ok:
            return

    settings.endGroup()

    return ('dbname=%s host=%s user=%s password=%s port=%s') % (db, host, user, passw, port)
