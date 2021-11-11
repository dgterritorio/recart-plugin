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
import os
from datetime import datetime
import math
import json

from enum import Enum
from pathlib import Path

from PyQt5 import uic
from PyQt5.QtWidgets import QDialog, QProgressDialog, QMessageBox, QAbstractItemView, QDialogButtonBox, QStyle
from PyQt5.QtCore import Qt, QThread, pyqtSlot, pyqtSignal, QVariant
from PyQt5.QtGui import QIntValidator, QStandardItemModel, QStandardItem

from qgis.core import QgsProject, QgsVectorLayer, QgsDataSourceUri
from qgis.gui import QgsFileWidget

from osgeo import gdal
from osgeo import ogr

from . import qgis_configs
from .postgis_helper import PostgisUtils
from .aux_export import displayList, recartStructure, fieldNameMap

from .convert.conf import dc
from .convert.gm_cart_import import CartImporter

FORM_CLASS, _ = uic.loadUiType(os.path.join(
    os.path.dirname(__file__), 'ui/convert_dialog.ui'))


class ConvertDialog(QDialog, FORM_CLASS):
    def __init__(self, iface, parent=None):
        super(ConvertDialog, self).__init__(parent)
        self.initialized = False
        self.setupUi(self)

        self.iface = iface
        self.buttonBox.button(
            QDialogButtonBox.Ok).clicked.connect(self.process)

        self.nddCombo.addItems(['ndd1', 'ndd2'])

        self.convertProcess = None

    def showEvent(self, event):
        super(ConvertDialog, self).showEvent(event)

        self.progressBar.setVisible(False)
        self.def_config = dc

        if not self.initialized:
            self.buttonBox.button(QDialogButtonBox.Cancel).setText("Fechar")
            self.buttonBox.button(QDialogButtonBox.Cancel).setIcon(self.style().standardIcon(QStyle.SP_DialogCancelButton))
            self.buttonBox.button(QDialogButtonBox.Ok).setText("Converter")
            self.buttonBox.button(QDialogButtonBox.Ok).setIcon(self.style().standardIcon(QStyle.SP_DialogOkButton))
            
            self.fillDataSources()
            self.initialized = True

    def closeEvent(self, event):
        super(ConvertDialog, self).closeEvent(event)

    def reject(self):
        if self.convertProcess is not None and self.convertProcess.running is True:
            self.convertProcess.cancel = True
            # self.progressBar.setVisible(False)
            # self.buttonBox.button(QDialogButtonBox.Ok).setEnabled(True)
            # self.buttonBox.button(QDialogButtonBox.Cancel).setText("Fechar")
            # self.buttonBox.button(QDialogButtonBox.Cancel).setIcon(self.style().standardIcon(QStyle.SP_DialogCancelButton))
        else:
            self.plainTextEdit.clear()
            super(ConvertDialog, self).reject()

    @pyqtSlot('PyQt_PyObject', name='writeText')
    def writeText(self, text):
        self.plainTextEdit.appendPlainText(text)

    def changeCustomMap(self, state):
        self.mapQgsFileWidget.setEnabled(state)

    def changeAliasMap(self, state):
        self.aliasQgsFileWidget.setEnabled(state)

    def changeInputFile(self, path):
        if not path:
            return

        self.fieldsComboBox.clear()

        test_file = QgsFileWidget.splitFilePaths(path)[0]
        data_source = gdal.OpenEx(test_file, gdal.OF_VECTOR)

        if data_source is not None:
            layer_count = data_source.GetLayerCount()
        else:
            self.inputQgsFileWidget.setFilePath(None)
            self.writeText('[Erro] Ficheiro não compatível')
            return

        if layer_count > 0:
            layer = data_source.GetLayerByIndex(0)

            fields = []
            feat_defn = layer.GetLayerDefn()
            for fi in range(feat_defn.GetFieldCount()):
                field_defn = feat_defn.GetFieldDefn(fi)
                fields.append(field_defn.GetName())

            self.fieldsComboBox.addItems(fields)

    def getConnection(self):
        return self.connCombo.currentText()

    def fillDataSources(self):
        self.connCombo.clear()
        dblist = qgis_configs.listDataSources()
        firstRow = 'Escolher conexão...' if len(
            dblist) > 0 else 'Sem conexões disponíveis'
        secondRow = 'Atualizar conexões...'
        self.connCombo.addItems([firstRow, secondRow] + dblist)

    def changeConn(self, newConnName):
        if newConnName == 'Atualizar conexões...':
            self.fillDataSources()
            self.plainTextEdit.appendPlainText("Conexões Postgis atualizadas")
            self.connCombo.setCurrentIndex(0)
        # else:
        #     if newConnName != 'Escolher conexão...' and newConnName != 'Sem conexões disponíveis' and newConnName != "":
        #         conString = qgis_configs.getConnString(self, newConnName)
        #         # self.plainTextEdit.appendPlainText(
        #         #     "New connection to: {0}\n".format(conString))
        #         utils = PostgisUtils(self, conString)
        #         try:
        #             schemas = utils.read_db_schemas()
        #             # self.plainTextEdit.appendPlainText(
        #             #     "Schemas: {0}\n".format(','.join(schemas)))
        #             self.schemaName.addItems(schemas)
        #         except ValueError as error:
        #             self.plainTextEdit.appendPlainText(
        #                 "[Erro]: {0}\n".format(error))

    def testValidOutDir(self):
        # res = False if not self.odirQgsFileWidget.filePath() else True
        res = True
        return res

    def testValidProcessing(self):
        # res = False if not self.odirQgsFileWidget.filePath() else True
        res = True
        res = (res and False) if not self.configQgsFileWidget.filePath() else (
            res and True)
        res = (res and False) if not self.fieldsComboBox.currentText() else (
            res and True)
        if self.cmapCheckBox.isChecked():
            res = (res and False) if not self.mapQgsFileWidget.filePath() else (
                res and True)
        if self.caliasCheckBox.isChecked():
            res = (res and False) if not self.aliasQgsFileWidget.filePath() else (
                res and True)

        res = (res and False) if not self.lineEdit.text() else (res and True)

        con = self.getConnection()
        res = (res and True) if con != 'Escolher conexão...' and con != 'Sem conexões disponíveis' and con != "" else (
            res and False)

        return res

    def exportDefConfig(self):
        if self.testValidOutDir():
            with open('conf.json', "w") as conf_file:
                conf_file.write(json.dumps(
                    self.def_config, indent=4, ensure_ascii=False))
                self.writeText(
                    '[Sucesso] Configuração base exportada para o diretório \'' + os.getcwd() + '\'')
        else:
            self.writeText('[Aviso] Selecione um diretório de output primeiro')

    def finishedConvert(self):
        self.progressBar.setVisible(False)
        self.buttonBox.button(QDialogButtonBox.Ok).setEnabled(True)
        self.buttonBox.button(QDialogButtonBox.Cancel).setText("Fechar")
        self.buttonBox.button(QDialogButtonBox.Cancel).setIcon(self.style().standardIcon(QStyle.SP_DialogCancelButton))

        self.convertProcess = None

    def process(self):
        if self.testValidProcessing():
            self.writeText("A converter camadas ...")
            self.progressBar.setVisible(True)

            cm = True if self.cmapCheckBox.isChecked() else False
            kwargs = {}
            kwargs['cod_field'] = self.fieldsComboBox.currentText()

            if self.caliasCheckBox.isChecked():
                kwargs['alias'] = self.aliasQgsFileWidget.filePath()

            kwargs['force_geom'] = self.forceGeomCheckBox.isChecked()
            kwargs['force_polygon'] = self.forcePolygonCheckBox.isChecked()
            kwargs['force_close'] = self.forceCloseCheckBox.isChecked()

            kwargs['use_layerName'] = self.overwriteLNCheckBox.isChecked()

            kwargs['schema'] = self.lineEdit.text()
            kwargs['ndd'] = self.nddCombo.currentText()

            conString = qgis_configs.getConnString(self, self.getConnection())

            if conString is None:
                self.writeText('[Aviso] Configuração inválida')
                self.progressBar.setVisible(False)
                return

            self.convertProcess = ConvertProcess(self.mapQgsFileWidget.filePath(),
                                                 cm, kwargs, self.inputQgsFileWidget.filePath(),
                                                 self.configQgsFileWidget.filePath(), conString)

            self.convertProcess.signal.connect(self.writeText)
            self.convertProcess.finished.connect(self.finishedConvert)

            self.iface.messageBar().pushMessage("Converter dados.")
            self.convertProcess.start()
            self.buttonBox.button(QDialogButtonBox.Ok).setEnabled(False)
            self.buttonBox.button(QDialogButtonBox.Cancel).setText("Cancelar")
            self.buttonBox.button(QDialogButtonBox.Cancel).setIcon(self.style().standardIcon(QStyle.SP_DialogDiscardButton))
        else:
            self.writeText('[Aviso] Configuração inválida')


class ConvertProcess(QThread):
    signal = pyqtSignal('PyQt_PyObject')

    def __init__(self, mapDir, cm, args, iptFile, outDir, outConn):
        QThread.__init__(self)

        now = datetime.now()
        self.prefix = now.strftime("%Y%m%d%H%M%S")

        self.mapDir = mapDir
        self.cm = cm
        self.args = args
        self.iptFile = iptFile
        self.outDir = outDir
        self.running = False
        self.cancel = False

        self.pgutils = PostgisUtils(self, outConn)

        self.actconn = None

    def write(self, text):
        self.signal.emit(text)

    def setCancel(self, state):
        self.cancel = state

        if state is True and self.actconn is not None:
            try:
                self.actconn.cancel()
            except Exception as e:
                self.actconn.close()
                self.actconn = None

        self.write("\t [Aviso] Operação cancelada")

    def run(self):
        self.running = True
        try:
            ci = CartImporter(self.mapDir, self.cm, self.write, **self.args)

            # ci.read_conf(self.cfgFile)

            for path in QgsFileWidget.splitFilePaths(self.iptFile):
                ci.read_file(path)

            if self.cancel is True:
                self.write("\t [Aviso] Operação cancelada")
                return

            ci.process_data()
            ci.pp_conf()
            ci.print_err_report()


            if self.cancel is True:
                self.write("\t [Aviso] Operação cancelada")
                return

            # ci.persist_data(self.outDir, os.path.basename(self.iptFile))
            # usar a datahora, em vez da lista de ficheiros de input
            ci.persist_data(self.outDir, self.prefix)

            if self.cancel is True:
                self.write("\t [Aviso] Operação cancelada")
                return

            self.actconn = self.pgutils.get_connection()

            for pth in ['_base.sql', '_features.sql', '_remaining.sql', '_errors.sql', '_layer_styles.sql']:
                if self.cancel:
                    break

                self.pgutils.run_file_with_conn(self.actconn, os.path.join(self.outDir, os.path.basename(self.prefix) + pth))

            self.actconn.close()
            self.actconn = None
            if self.cancel:
                self.write("\t [Aviso] Operação cancelada")
                return

            ci.print_import_report()

            self.running = False
        except Exception as e:
            if not self.cancel:
                self.write("[Erro]")
                self.write(("\tException: {}".format(e)))

    def runSql(self, path):
        self.pgutils.run_file(path)
