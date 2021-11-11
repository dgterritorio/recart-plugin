# -*- coding: utf-8 -*-
"""
/***************************************************************************
 recartDGT
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
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
 This script initializes the plugin, making it known to QGIS.
"""


# noinspection PyPep8Naming
def classFactory(iface):  # pylint: disable=invalid-name
    """Load class from file.

    :param iface: A QGIS interface instance.
    :type iface: QgsInterface
    """
    #
    from .recartDGT import recartDGT
    return recartDGT(iface)
