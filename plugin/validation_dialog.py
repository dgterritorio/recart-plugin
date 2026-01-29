# -*- coding: utf-8 -*-
"""
/***************************************************************************
 RecartDGT
                                 A QGIS plugin
 Validate cartography datasets
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
import os, subprocess, platform
import json
import re

from datetime import datetime

from qgis.PyQt import uic
from qgis.PyQt.QtWidgets import QDialog, QDialogButtonBox, QMessageBox, QHeaderView, QCheckBox, QStyle
from qgis.PyQt.QtCore import Qt, QThread, pyqtSlot, pyqtSignal, QMetaType
from qgis.PyQt.QtGui import QStandardItemModel, QStandardItem, QFont

from qgis.core import Qgis, QgsProject, QgsVectorLayer, QgsStyle, QgsPrintLayout, QgsLayoutExporter, QgsLayoutItem, QgsLayoutItemTextTable, QgsLayoutTableColumn, QgsLayoutFrame, QgsLayoutSize, QgsLayoutPoint, QgsUnitTypes, QgsLayoutItemPage, QgsLayoutItemLabel, QgsCoordinateReferenceSystem, QgsFields, QgsField
from qgis.gui import QgsFileWidget
from qgis.utils import iface

from . import qgis_configs
from .postgis_helper import PostgisUtils
from .aux_export import displayList

import time


FORM_CLASS, _ = uic.loadUiType(os.path.join(
    os.path.dirname(__file__), 'ui/validation_dialog.ui'))


class ValidationDialog(QDialog, FORM_CLASS):
    def __init__(self, iface, parent=None):
        super(ValidationDialog, self).__init__(parent)
        self.initialized = False
        self.newConn = True
        self.setupUi(self)

        self.iface = iface
        self.buttonBox.button(
            QDialogButtonBox.StandardButton.Ok).clicked.connect(self.process)

        self.buttonBox.button(
            QDialogButtonBox.StandardButton.Reset).clicked.connect(self.reset)

        self.ndCombo.addItems(['NdD1', 'NdD2'])
        self.vrsCombo.addItems(['Desconhecida', 'v1.1.2', 'v2.0.1', 'v2.0.2'])
        
        self.groupBox.setVisible(False)

        self.validateProcess = None
        self.createProcess = None

        self.structure_errors = []
        self.value_list_errors = []

        self.pgutils = None
        self.ruleSetup = False
        self.baseSetup = False

        self.srsid = 0
        self.vrs = 'Desconhecida'

    def showEvent(self, event):
        super(ValidationDialog, self).showEvent(event)

        self.progressBar.setVisible(False)
        self.createProcess = None
        self.updateProcess = None

        if not self.initialized:
            self.buttonBox.button(QDialogButtonBox.StandardButton.Cancel).setText("Fechar")
            self.buttonBox.button(QDialogButtonBox.StandardButton.Cancel).setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DialogCancelButton))
            self.buttonBox.button(QDialogButtonBox.StandardButton.Ok).setText("Validar")
            self.buttonBox.button(QDialogButtonBox.StandardButton.Ok).setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DialogOkButton))
            self.buttonBox.button(QDialogButtonBox.StandardButton.Ok).setEnabled(True)

            self.tableView.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Interactive)
            self.tableView.horizontalHeader().setStretchLastSection(True)
            self.tableView.setVisible(False)
            self.checkBoxAll.setVisible(False)

            self.fillDataSources()

            crs = QgsCoordinateReferenceSystem("EPSG:3763")
            self.mQgsProjectionSelectionWidget.setCrs( crs )
            
            self.comboBoxOps.addItems(['Igual', 'Diferente', 'Maior', 'Menor', 'Maior ou igual', 'Menor ou igual'])

            self.mQgsFileWidget.setStorageMode(QgsFileWidget.GetDirectory)

            self.isRunning = False
            self.initialized = True

    def closeEvent(self, event):
        super(ValidationDialog, self).closeEvent(event)

    def reject(self):
        if self.createProcess is not None:
            self.createProcess.setCancel(True)
            self.isRunning = False
        elif self.validateProcess is not None:
            self.validateProcess.setCancel(True)
            self.buttonBox.button(QDialogButtonBox.StandardButton.Cancel).setText("Fechar")
            self.buttonBox.button(QDialogButtonBox.StandardButton.Cancel).setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DialogCancelButton))
            self.buttonBox.button(QDialogButtonBox.StandardButton.Ok).setEnabled(True)
            self.isRunning = False
        else:
            self.plainTextEdit.clear()
            super(ValidationDialog, self).reject()

    def toggleEdit(self, state):
        # self.ignoreSusp.setEnabled(state)
        # self.ignorarSub.setEnabled(state)
        # self.ignorarSolo.setEnabled(state)
        self.ignorarFict.setEnabled(state)
        self.ignorarDesc.setEnabled(state)

        self.rg1_ndd1.setEnabled(state)
        self.rg1_ndd2.setEnabled(state)
        self.rg4_ndd1.setEnabled(state)
        self.rg4_ndd2.setEnabled(state)
        self.re3_2_ndd1.setEnabled(state)
        self.re3_2_ndd2.setEnabled(state)
        self.re3_3_ndd1.setEnabled(state)
        self.re3_3_ndd2.setEnabled(state)
        self.re7_1_ndd1.setEnabled(state)
        self.re7_1_ndd2.setEnabled(state)
        self.re7_8_ndd1.setEnabled(state)
        self.re7_8_ndd2.setEnabled(state)

    @pyqtSlot('PyQt_PyObject', name='writeText')
    def writeText(self, text):
        times = datetime.now()
        formated = times.strftime("%Y-%m-%d %H:%M:%S")
        self.plainTextEdit.appendPlainText('{} {}'.format(formated, text))

    def getConnection(self):
        return self.connCombo.currentText()

    def fillDataSources(self):
        self.connCombo.clear()
        dblist = qgis_configs.listDataSources()
        firstRow = 'Escolher conexão...' if len(
            dblist) > 0 else 'Sem conexões disponíveis'
        secondRow = 'Atualizar conexões...'
        self.connCombo.addItems([firstRow, secondRow] + dblist)

    # a checkbox está disabled na UI, pelo que este método nunca é invocado
    def validate3dChange(self, state):
        self.actconn = self.pgutils.get_or_create_connection()
        if state is False and self.ruleSetup:
            try:
                self.pgutils.run_query_with_conn(self.actconn,
                    "update validation.rules set run = false \
                        where '{}' =any(versoes) and \
                        (code ilike 're3_2' or code ilike 'rg_4' or code ilike 'rg_4_1' or code ilike 'rg_4_2');".format(self.vrs))
                self.updateTable()
            except Exception as e:
                self.writeText("[Erro 1]")
                self.writeText(("\tException: {}".format(e)))
                self.tabWidget.setCurrentIndex(1)

    def validateAllChange(self, state):
        self.actconn = self.pgutils.get_or_create_connection()
        if state is True and self.ruleSetup:
            try:
                self.pgutils.run_query_with_conn(self.actconn,
                    "update validation.rules_area set run = true\
                        where '{}' =any(versoes);".format(self.vrs))
                self.pgutils.run_query_with_conn(self.actconn,
                    "update validation.rules set run = true\
                        where '{}' =any(versoes);".format(self.vrs))

                self.updateTable()
                self.checkBox.setChecked(True)
            except Exception as e:
                self.writeText("[Erro 2]")
                self.writeText(("\tException: {}".format(e)))        
        if state is False and self.ruleSetup:
            try:
                self.pgutils.run_query_with_conn(self.actconn,
                    "update validation.rules_area set run = false \
                        where '{}' =any(versoes);".format(self.vrs))
                self.pgutils.run_query_with_conn(self.actconn,
                    "update validation.rules set run = false \
                        where '{}' =any(versoes);".format(self.vrs))
                self.updateTable()
                self.checkBox.setChecked(False)
            except Exception as e:
                self.writeText("[Erro 3]")
                self.writeText(("\tException: {}".format(e)))
                self.tabWidget.setCurrentIndex(1)

    def setRuleState(self, state):
        self.actconn = self.pgutils.get_or_create_connection()
        rcode = self.sender().property("code")
        rstate = 'true' if state else 'false'

        try:
            self.pgutils.run_query_with_conn(self.actconn, "update validation.rules_area set run = {} \
                where '{}' =any(versoes) and code ilike '{}';".format(rstate, self.vrs, rcode))
            self.pgutils.run_query_with_conn(self.actconn, "update validation.rules set run = {} \
                where '{}' =any(versoes) and code ilike '{}';".format(rstate, self.vrs, rcode))

            if (rcode == 're3_2' or rcode == 'rg_4' or rcode == 'rg_4_1' or rcode == 'rg_4_2') and state is True:
                self.checkBox.setChecked(True)
        except Exception as e:
            self.writeText("[Erro 4]")
            self.writeText(("\tException: {}".format(e)))
            self.tabWidget.setCurrentIndex(1)

    def updateTable(self):
        self.actconn = self.pgutils.get_or_create_connection()
        try:
            report_table = "validation.rules_area_report_view" if self.is_sections.isChecked() else "validation.rules"
            report = self.pgutils.run_query_with_conn(self.actconn,
                "select code, name, total, good, bad, run from {} \
                    where '{}' =any(versoes) \
                    order by dorder asc;".format(report_table, self.vrs))

            model = self.tableView.model()

            self.tableView.setUpdatesEnabled(False)
            model.clear()
            model.setHorizontalHeaderLabels(
                ['Código', 'Nome', 'Elementos', 'Corretos', 'Erros', 'Correr?'])

            rn = 0
            for row in report:
                model.appendRow([QStandardItem(row[0]), QStandardItem(row[1]), QStandardItem(
                    str(row[2])), QStandardItem(str(row[3])), QStandardItem(str(row[4]))])

                cb = QCheckBox()
                cb.setProperty("code", row[0])

                state = row[5]
                cb.setChecked(state)
                cb.toggled.connect(self.setRuleState)
                self.tableView.setIndexWidget(model.index(rn, 5), cb)
                rn = rn + 1

            self.tableView.setUpdatesEnabled(True)
            if self.updateProcess is not None:
                self.updateProcess.setUpdated(False)
        except Exception as e:
            self.writeText("[Erro 5]")
            self.writeText(("\tException: {}".format(e)))
            self.tabWidget.setCurrentIndex(1)

    def getAreaTables(self):
        self.actconn = self.pgutils.get_or_create_connection()
        tables = []

        self.areaComboBox.clear()
        try:
            tables = self.pgutils.run_query_with_conn(self.actconn,
                "with aggr_cols as (\
	                SELECT table_schema, table_name, string_agg(column_name::varchar, '|') as cols FROM information_schema.columns\
	                    where table_schema = 'validation' or (table_schema = 'public' and table_name = any('{distrito,municipio,concelho,freguesia}'))\
	                    	or (table_schema = 'reconhecimento_campo' and table_name='samples')\
	                group by table_schema, table_name\
                ) select table_schema || '.' || table_name from aggr_cols\
					where cols ilike '%identificador%' and cols ilike '%geometria%';")
            if tables and len(tables) > 0:
                self.areaComboBox.addItems([row[0] for row in tables])
        except Exception as e:
            self.writeText("[Erro 13]")
            self.writeText(("\tException: {}".format(e)))
            self.tabWidget.setCurrentIndex(1)

    def changeField(self, field):
        for f in self.mFieldComboBox.fields():
            if f.name() == field:
                self.changeOps(f.type())
                break

    def changeOps(self, type):
        self.comboBoxOps.clear()
        if type == QMetaType.Type.QDateTime or type == QMetaType.Type.Int or type == QMetaType.Type.Double:
            self.comboBoxOps.addItems(['Igual', 'Diferente', 'Maior', 'Menor', 'Maior ou igual', 'Menor ou igual'])
        elif type == QMetaType.Type.Bool or type == QMetaType.Type.QUuid or type == QMetaType.Type.QString:
            self.comboBoxOps.addItems(['Igual', 'Diferente'])

    def areaTableChange(self, text):
        self.actconn = self.pgutils.get_or_create_connection()
        try:
            aux = text.split('.')
            if len(aux) != 2:
                return

            ts = aux[0]
            tn = aux[1]

            campos = self.pgutils.run_query_with_conn(self.actconn,
                "SELECT column_name, data_type FROM information_schema.columns \
                    where table_schema='{}' and table_name='{}';".format(ts, tn))
            if campos and len(campos) > 0:
                fields = QgsFields()
                for c in campos:
                    if len(c) != 2:
                        continue
                    if c[1] == 'date' or c[1].startswith('timestamp'):
                        fields.append(QgsField(c[0], QMetaType.Type.QDateTime))
                    elif c[1] == 'integer' or c[1] == 'bigint' or c[1] == 'smallint':
                        fields.append(QgsField(c[0], QMetaType.Type.Int))
                    elif c[1] == 'double precision' or c[1] == 'real' or c[1] == 'numeric':
                        fields.append(QgsField(c[0], QMetaType.Type.Double))
                    elif c[1] == '"char"' or c[1] == 'character varying' or c[1] == 'text':
                        fields.append(QgsField(c[0], QMetaType.Type.QString))
                    elif c[1] == 'boolean':
                        fields.append(QgsField(c[0], QMetaType.Type.Bool))
                    elif c[1] == 'uuid':
                        fields.append(QgsField(c[0], QMetaType.Type.QUuid))
                    else:
                        fields.append(QgsField(c[0], QMetaType.Type.QString))

                self.mFieldComboBox.setFields(fields)
                self.changeField(fields.field(0).name())
        except Exception as e:
            self.writeText("[Erro 14]")
            self.writeText(("\tException: {} {}".format( Qgis.QGIS_VERSION, e)))
            self.tabWidget.setCurrentIndex(1)

    def testDbVersion(self):
        self.actconn = self.pgutils.get_or_create_connection()
        finddbquery = 'select count(*), substring( version() from \'P\\w+ \\w+\') as versao from {schema}.valor_construcao_linear;'
        
        self.schema = str(self.schemaName.currentText())
        
        cnt = re.sub(r"{schema}", self.schema, finddbquery)

        try:
            result = self.pgutils.run_query_with_conn(self.actconn, cnt)
            if result and len(result) > 0:
                if result[0][0] == 9:
                    self.vrs = 'v1.1.2'
                elif result[0][0] == 11:
                    self.vrs = 'v2.0.1'
                elif result[0][0] == 10:
                    self.vrs = 'v2.0.2'
                else:
                    self.vrs = 'Desconhecida'                
                self.writeText("[Sucesso] Versão das regras: {0} Versão {1}\n".format(self.vrs, result[0][1]))
                self.vrsCombo.setCurrentText(self.vrs)
            else:
                self.writeText("[Aviso] {0}\n".format("Não foi possível detetar a versão das regras"))
        except Exception as e:
            self.writeText("[Erro 15] Falha ao detetar a versão das regras")
            self.vrs = 'Desconhecida'
            self.vrsCombo.setCurrentText(self.vrs)
            # self.writeText(("\tException: {}".format(e)))
            self.tabWidget.setCurrentIndex(1)

        if self.vrs != 'Desconhecida':
            self.vrsCombo.setEnabled(False)
        else:
            self.vrsCombo.setEnabled(True)

    def testValidationRules(self):
        self.actconn = self.pgutils.get_or_create_connection()
        allChecked = True

        if self.iface.pluginManagerInterface().pluginMetadata('recartDGT') is not None:
            self.writeText("recartDGT v{}".format(self.iface.pluginManagerInterface().pluginMetadata('recartDGT')['version_installed']))

        self.writeText("A carregar a versão das regras {}...".format(self.vrs if self.vrs is not None else 'Desconhecida'))
        try:
            report_table = "validation.rules_area_report_view" if self.is_sections.isChecked() else "validation.rules"

            report = self.pgutils.run_query_with_conn(self.actconn,
                "select code, name, total, good, bad, run from {}\
                    where '{}' =any(versoes) \
                    order by dorder asc;".format(report_table, self.vrs))

            self.tableView.setVisible(True)
            self.pushButton.setVisible(False)
            self.checkBoxAll.setVisible(True)

            model = self.tableView.model()
            if model is None or model.rowCount() == 0:
                model = QStandardItemModel()
                self.tableView.setModel(model)
            else:
                model.clear()

            model.setHorizontalHeaderLabels(
                ['Código', 'Nome', 'Elementos', 'Corretos', 'Erros', 'Correr?'])

            rn = 0
            for row in report:
                # self.writeText("{} Regra {}...".format(rn, row[0]))
                model.appendRow([QStandardItem(row[0]), QStandardItem(row[1]), QStandardItem(
                    str(row[2])), QStandardItem(str(row[3])), QStandardItem(str(row[4]))])

                cb = QCheckBox()
                cb.setProperty("code", row[0])

                state = row[5]
                cb.setChecked(state)
                cb.toggled.connect(self.setRuleState)
                self.tableView.setIndexWidget(model.index(rn, 5), cb)

                if not state:
                    allChecked = False

                rn = rn + 1

            self.checkBoxAll.setChecked(allChecked)

            self.ruleSetup = True
            self.relButton.setEnabled(True)
        except Exception as e:
            print(e)
            self.ruleSetup = False
            self.relButton.setEnabled(False)
            self.tableView.setVisible(False)
            self.checkBoxAll.setVisible(False)
            self.pushButton.setVisible(True)

    def changeConn(self, newConnName):
        self.newConn = True
        self.schemaName.clear()
        self.vrsCombo.setCurrentText('Desconhecida')
        self.vrs = 'Desconhecida'
        
        if newConnName == 'Atualizar conexões...':
            self.fillDataSources()
            self.plainTextEdit.appendPlainText("Conexões Postgis atualizadas")
            self.connCombo.setCurrentIndex(0)
        else:
            if newConnName != 'Escolher conexão...' and newConnName != 'Sem conexões disponíveis' and newConnName != "":
                try:
                    self.conString = qgis_configs.getConnString(self, newConnName)
                    # self.plainTextEdit.appendPlainText(
                    #     "New connection to: {0}\n".format(conString))
                    self.pgutils = PostgisUtils(self, self.conString)
                
                    schemas = self.pgutils.read_db_schemas_keep_conn()
                    # self.plainTextEdit.appendPlainText(
                    #     "Schemas: {0}\n".format(','.join(schemas)))
                    # self.schemaName.clear()
                    if not len(schemas) > 0:
                        self.plainTextEdit.appendPlainText("[Aviso] {0}\n".format("Conexão inválida"))
                        self.fillDataSources()
                        self.tabWidget.setCurrentIndex(1)
                        return

                    self.schemaName.addItems(schemas)
                    self.schemaName.setCurrentIndex(schemas.index('public') if 'public' in schemas else 0)

                    model = self.tableView.model()
                    if model is not None:
                        model.clear()

                    self.testDbVersion()
                    self.testValidationRules()
                    self.getAreaTables()
                    self.newConn = False
                except Exception as error:
                    self.conString = None
                    self.plainTextEdit.appendPlainText(
                        "[Erro 6]: {0}\n".format(error))
                    self.tabWidget.setCurrentIndex(1)
            else:
                self.conString = None

    def testValidProcessing(self):
        res = True
        con = self.getConnection()
        res = (res and True) if con != 'Escolher conexão...' and con != 'Sem conexões disponíveis' and con != "" else (
            res and False)
        res = res and self.ruleSetup

        return res

    def createTable(self, layout, offsetx, offsety, size, columns, rows):
        table = QgsLayoutItemTextTable(layout)
        table.setWrapBehavior(1)
        layout.addMultiFrame(table)

        table.setColumns(columns)

        for r in rows:
            table.addRow(map(str, r))

        frame = QgsLayoutFrame(layout, table)
        frame.attemptResize(size, True)
        frame.attemptMove(QgsLayoutPoint(10 + offsetx, 10 +
                                         offsety, QgsUnitTypes.LayoutMillimeters))
        table.addFrame(frame)

    def getRule(self, rules, code):
        result = None

        for rule in rules:
            if rule[0] == code:
                result = rule[1]

        return result

    # Process title to use in report filenam
    def sanitize_filename(self, title):
        keepcharacters = (' ', '.', '_')
        fn = "".join(c for c in title if c.isalnum() or c in keepcharacters).rstrip()

        return fn

    def exportRel(self):
        self.actconn = self.pgutils.get_or_create_connection()
        if not self.ruleSetup:
            self.writeText("[Aviso] Não é possível imprimir relatório")
            return
        try:
            report_table = "validation.rules_area_report_view" if self.is_sections.isChecked() else "validation.rules"
            summary = self.pgutils.run_query_with_conn(self.actconn,
                "select code, name, total, good, bad from {} \
                    where '{}' =any(versoes) \
                    order by dorder asc;".format(report_table, self.vrs))

            rq = "SELECT (REGEXP_MATCHES(relname, '([a-z_0-9]+)_rg|([a-z_0-9]+)_re'))[1] as objeto1, (REGEXP_MATCHES(relname, '([a-z_0-9]+)_rg|([a-z_0-9]+)_re'))[2] as objeto2,"
            rq = rq + " (REGEXP_MATCHES(relname, '[a-z_0-9]+_(rg[0-9_]*)|[a-z_0-9]+_(re[0-9_]*)'))[1] as codigo1, (REGEXP_MATCHES(relname, '[a-z_0-9]+_(rg[0-9_]*)|[a-z_0-9]+_(re[0-9_]*)'))[2] as codigo2, n_live_tup"
            rq = rq + " FROM pg_stat_user_tables where schemaname = 'errors' and n_live_tup > 0 ORDER BY codigo1, codigo2, n_live_tup DESC;"
            report = self.pgutils.run_query_with_conn(self.actconn, rq)
            
            vq = "select tabela, atributo, valor, numero from validation.consistencia_valores_report order by tabela, atributo, valor;"
            vreport = self.pgutils.run_query_with_conn(self.actconn, vq)

            times = datetime.now()
            footnote = times.strftime("%Y-%m-%d %H:%M:%S") +\
                " | Recart " + self.vrs + " | " + self.ndCombo.currentText()

            project = QgsProject.instance()
            layout = QgsPrintLayout(project)
            layout.initializeDefaults()

            pages = layout.pageCollection()
            pages.beginPageSizeChange()

            page = pages.page(0)
            page.setPageSize('A4', QgsLayoutItemPage.Landscape)
            pages.endPageSizeChange()
            pageCenter = page.pageSize().width() / 2
            # print(page.pageSize().height())

            title = QgsLayoutItemLabel(layout)
            title.setText('Relatório Validação Automática')
            title.setFont(QFont('Arial', 30))
            title.adjustSizeToText()
            title.setReferencePoint(QgsLayoutItem.UpperMiddle)
            title.attemptMove(QgsLayoutPoint(pageCenter, 5))
            layout.addItem(title)

            sp = 20
            if self.lineEdit.text():
                section = QgsLayoutItemLabel(layout)
                section.setText(str(self.lineEdit.text()))
                section.setFont(QFont('Arial', 20, 75))
                section.adjustSizeToText()
                section.attemptMove(QgsLayoutPoint(8, 20))
                layout.addItem(section)
                sp = 30

            section = QgsLayoutItemLabel(layout)
            section.setText('Sumário')
            section.setFont(QFont('Arial', 14, 75))
            section.adjustSizeToText()
            section.attemptMove(QgsLayoutPoint(8, sp))
            layout.addItem(section)

            time = QgsLayoutItemLabel(layout)
            time.setText(footnote)
            time.setFont(QFont('Arial', 10, 25))
            time.adjustSizeToText()
            time.attemptMove(QgsLayoutPoint(8, page.pageSize().height()-8))
            layout.addItem(time)

            page2 = QgsLayoutItemPage(layout)
            page2.setPageSize('A4', QgsLayoutItemPage.Landscape)
            pages.addPage(page2)

            cols = [QgsLayoutTableColumn(), QgsLayoutTableColumn(),
                    QgsLayoutTableColumn(), QgsLayoutTableColumn(),
                    QgsLayoutTableColumn()]
            cols[0].setHeading("Código")
            cols[0].setWidth(20)
            cols[1].setHeading("Regra")
            cols[1].setWidth(150)
            cols[2].setHeading("Elementos")
            cols[2].setWidth(25)
            cols[3].setHeading("Corretos")
            cols[3].setWidth(25)
            cols[4].setHeading("Erros")
            cols[4].setWidth(25)
            self.createTable(layout, 12, sp, QgsLayoutSize(
                270, 210), cols, summary[:25])
            self.createTable(layout, 12, 210+20, QgsLayoutSize(
                270, 210), cols, summary[25:50])

            time = QgsLayoutItemLabel(layout)
            time.setText(footnote)
            time.setFont(QFont('Arial', 10, 25))
            time.adjustSizeToText()
            time.attemptMove(QgsLayoutPoint(8, 220+page.pageSize().height()-8))
            layout.addItem(time)

            page3 = QgsLayoutItemPage(layout)
            page3.setPageSize('A4', QgsLayoutItemPage.Landscape)
            pages.addPage(page3)

            self.createTable(layout, 12, 420+20, QgsLayoutSize(
                270, 210), cols, summary[50:])

            time = QgsLayoutItemLabel(layout)
            time.setText(footnote)
            time.setFont(QFont('Arial', 10, 25))
            time.adjustSizeToText()
            time.attemptMove(QgsLayoutPoint(8, 440+page.pageSize().height()-8))
            layout.addItem(time)

            # protect case where there is nothing to report
            if report is not None:

                themes = {}
                for row in report:
                    linha = []
                    if row[0] is not None:
                        slayer = row[0]
                        linha = [row[2], self.getRule(summary, row[2]), row[0], row[4]]
                    elif row[1] is not None:
                        slayer = row[1]
                        linha = [row[3], self.getRule(summary, row[3]), row[1], row[4]]
                    else:
                        print('-----')
                        print(row)

                    if slayer is not None:
                        key = displayList[slayer]["name"]
                        if key not in themes:
                            themes[key] = [linha]
                        else:
                            themes[key].append(linha)

                tabOff = 630
                if len(self.structure_errors) > 0:
                    npage = QgsLayoutItemPage(layout)
                    npage.setPageSize('A4', QgsLayoutItemPage.Landscape)
                    pages.addPage(npage)

                    section = QgsLayoutItemLabel(layout)
                    section.setText('Erros de Estrutura da Base de Dados')
                    section.setFont(QFont('Arial', 14, 75))
                    section.adjustSizeToText()
                    section.attemptMove(QgsLayoutPoint(8, 35 + tabOff))
                    layout.addItem(section)

                    cols = [QgsLayoutTableColumn(), QgsLayoutTableColumn()]
                    cols[0].setHeading("Tabela")
                    cols[0].setWidth(80)
                    cols[1].setHeading("Campos esperados")
                    cols[1].setWidth(160)

                    self.createTable(layout, 12, 35 + tabOff, QgsLayoutSize(270, 190),
                                    cols, self.structure_errors)

                    time = QgsLayoutItemLabel(layout)
                    time.setText(footnote)
                    time.setFont(QFont('Arial', 10, 25))
                    time.adjustSizeToText()
                    time.attemptMove(QgsLayoutPoint(8, 230+tabOff))
                    layout.addItem(time)

                    tabOff = tabOff + 220

                if len(self.value_list_errors) > 0:
                    npage = QgsLayoutItemPage(layout)
                    npage.setPageSize('A4', QgsLayoutItemPage.Landscape)
                    pages.addPage(npage)

                    section = QgsLayoutItemLabel(layout)
                    section.setText('Erros nas Listas de Valores')
                    section.setFont(QFont('Arial', 14, 75))
                    section.adjustSizeToText()
                    section.attemptMove(QgsLayoutPoint(8, 35 + tabOff))
                    layout.addItem(section)

                    cols = [QgsLayoutTableColumn(), QgsLayoutTableColumn(), QgsLayoutTableColumn()]
                    cols[0].setHeading("Tabela")
                    cols[0].setWidth(80)
                    cols[1].setHeading("Identificador esperado")
                    cols[1].setWidth(40)
                    cols[2].setHeading("Descrição esperada")
                    cols[2].setWidth(120)

                    self.createTable(layout, 12, 35 + tabOff, QgsLayoutSize(270, 190),
                                    cols, self.value_list_errors)

                    time = QgsLayoutItemLabel(layout)
                    time.setText(footnote)
                    time.setFont(QFont('Arial', 10, 25))
                    time.adjustSizeToText()
                    time.attemptMove(QgsLayoutPoint(8, 230+tabOff))
                    layout.addItem(time)

                    tabOff = tabOff + 220

                if vreport is not None and len(vreport) > 0:
                    npage = QgsLayoutItemPage(layout)
                    npage.setPageSize('A4', QgsLayoutItemPage.Landscape)
                    pages.addPage(npage)

                    section = QgsLayoutItemLabel(layout)
                    section.setText('Erros de Consistência de Domínio')
                    section.setFont(QFont('Arial', 14, 75))
                    section.adjustSizeToText()
                    section.attemptMove(QgsLayoutPoint(8, 35 + tabOff))
                    layout.addItem(section)

                    cols = [QgsLayoutTableColumn(), QgsLayoutTableColumn(),
                            QgsLayoutTableColumn(), QgsLayoutTableColumn()]
                    cols[0].setHeading("Objeto")
                    cols[0].setWidth(80)
                    cols[1].setHeading("Atributo")
                    cols[1].setWidth(85)
                    cols[2].setHeading("Erro")
                    cols[2].setWidth(30)
                    cols[3].setHeading("Número de Ocorrências")
                    cols[3].setWidth(50)

                    self.createTable(layout, 12, 35 + tabOff, QgsLayoutSize(270, 190),
                                    cols, vreport)

                    time = QgsLayoutItemLabel(layout)
                    time.setText(footnote)
                    time.setFont(QFont('Arial', 10, 25))
                    time.adjustSizeToText()
                    time.attemptMove(QgsLayoutPoint(8, 230+tabOff))
                    layout.addItem(time)

                    tabOff = tabOff + 220

                for thm in sorted(themes):
                    npage = QgsLayoutItemPage(layout)
                    npage.setPageSize('A4', QgsLayoutItemPage.Landscape)
                    pages.addPage(npage)

                    section = QgsLayoutItemLabel(layout)
                    section.setText('Erros no Tema ' + str(thm))
                    section.setFont(QFont('Arial', 14, 75))
                    section.adjustSizeToText()
                    section.attemptMove(QgsLayoutPoint(8, 35 + tabOff))
                    layout.addItem(section)

                    cols = [QgsLayoutTableColumn(), QgsLayoutTableColumn(),
                            QgsLayoutTableColumn(), QgsLayoutTableColumn()]
                    cols[0].setHeading("Código")
                    cols[0].setWidth(20)
                    cols[1].setHeading("Regra")
                    cols[1].setWidth(150)
                    cols[2].setHeading("Objeto")
                    cols[2].setWidth(55)
                    cols[3].setHeading("Erros")
                    cols[3].setWidth(20)

                    self.createTable(layout, 12, 35 + tabOff, QgsLayoutSize(270, 190),
                                    cols, themes[thm])

                    time = QgsLayoutItemLabel(layout)
                    time.setText(footnote)
                    time.setFont(QFont('Arial', 10, 25))
                    time.adjustSizeToText()
                    time.attemptMove(QgsLayoutPoint(8, 230+tabOff))
                    layout.addItem(time)

                    tabOff = tabOff + 220

            title = self.lineEdit.text() if self.lineEdit.text() else "report"

            filepath = os.path.join(os.getcwd(), self.sanitize_filename(title) + \
                times.strftime("%Y%m%d%H%M%S") + ".pdf")

            if self.mQgsFileWidget.filePath() != "":
                filepath = os.path.join(self.mQgsFileWidget.filePath(), self.sanitize_filename(title) + \
                    times.strftime("%Y%m%d%H%M%S") + ".pdf")

            exporter = QgsLayoutExporter(layout)
            exporter.exportToPdf(
                filepath, QgsLayoutExporter.PdfExportSettings())

            self.writeText("[Sucesso] Relatório gerado em '"  + filepath + "'" )

            # open pdf
            if platform.system() == 'Darwin':
                subprocess.call(('open', filepath))
            elif platform.system() == 'Windows':
                os.startfile(filepath)
            else:
                subprocess.call(('xdg-open', filepath))

        except Exception as e:
            self.writeText("[Erro 7]")
            self.writeText(("\tException: {}".format(e)))
            self.tabWidget.setCurrentIndex(1)

    def changeSchema(self):
        if not self.newConn:
            self.testDbVersion()

    def setupRules(self):
        self.actconn = self.pgutils.get_or_create_connection()
        self.bp = os.path.dirname(os.path.realpath(__file__))
        self.schema = str(self.schemaName.currentText())
        try:
            with open(self.bp + '/validation_rules.sql', 'r', encoding='utf-8') as f:
                cnt = f.read()
            cnt = re.sub(r"{schema}", self.schema, cnt)
            self.pgutils.run_query_with_conn(self.actconn, cnt)
            self.testValidationRules()
            self.getAreaTables()
        except Exception as e:
            self.writeText("[Erro 6]")
            self.writeText(("\tException: {}".format(e)))
            self.tabWidget.setCurrentIndex(1)

    def finishedValidate(self):
        self.updateProcess.setStop(True)
        self.updateTable()
        self.buttonBox.button(QDialogButtonBox.StandardButton.Cancel).setText("Fechar")
        self.buttonBox.button(QDialogButtonBox.StandardButton.Cancel).setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DialogCancelButton))

        self.structure_errors = self.validateProcess.structure_errors
        self.value_list_errors = self.validateProcess.value_list_errors

        if not self.validateProcess.cancel is True:
            # conString = qgis_configs.getConnString(self, self.getConnection())
            self.schema = str(self.schemaName.currentText())

            self.addLayersProcess = AddLayersProcess(self.conString, self.schema, self.srsid)
            self.addLayersProcess.signal.connect(self.writeText)
            self.addLayersProcess.addLayer.connect(self.addLayer)
            self.addLayersProcess.finished.connect(self.finishedAddLayers)
            self.addLayersProcess.start()
        else:
            self.isRunning = False
            self.progressBar.setVisible(False)
            self.buttonBox.button(QDialogButtonBox.StandardButton.Ok).setEnabled(True)

        self.validateProcess = None

    def finishedAddLayers(self):
        self.isRunning = False
        self.progressBar.setVisible(False)
        self.buttonBox.button(QDialogButtonBox.StandardButton.Ok).setEnabled(True)

        self.writeText("Terminada a validação")


    def getOp(self, op):
        if op == 'Igual':
            return '='
        elif op == 'Diferente':
            return '!='
        elif op == 'Maior':
            return '>'
        elif op == 'Menor':
            return '<'
        elif op == 'Maior ou igual':
            return '>='
        elif op == 'Menor ou igual':
            return '<='
        else:
            return None

    def finishedCreate(self):
        if self.createProcess is not None and not self.createProcess.cancel is True:
            # conString = qgis_configs.getConnString(self, self.getConnection())
            schema = str(self.schemaName.currentText())
            # self.vrs = self.createProcess.vrs
            self.baseSetup = True


            args = {
                'rg1_ndd1': self.rg1_ndd1.text(),
                'rg1_ndd2': self.rg1_ndd2.text(),
                're3_2_ndd1': self.re3_2_ndd1.text(),
                're3_2_ndd2': self.re3_2_ndd2.text(),
                're3_3_ndd1': self.re3_3_ndd1.text(),
                're3_3_ndd2': self.re3_3_ndd2.text(),
                're7_1_ndd1': self.re7_1_ndd1.text(),
                're7_1_ndd2': self.re7_1_ndd2.text(),
                're7_8_ndd1': self.re7_8_ndd1.text(),
                're7_8_ndd2': self.re7_8_ndd2.text(),
                'desvio_3D': self.rg4_ndd1.text() if self.ndCombo.currentText() == 'NdD1' else self.rg4_ndd2.text()
            }

            fltr = None
            if self.fltrValue is not None and self.fltrValue.text() != "":
                fltr = "{} {} '{}'".format(self.mFieldComboBox.currentText(), self.getOp(self.comboBoxOps.currentText()),
                                           self.fltrValue.text())

            self.validateProcess = ValidateProcess(self.conString, schema, self.ndCombo.currentText(), self.vrs, self.is_sections, self.areaComboBox.currentText(), args, fltr, self.pgutils)

            self.validateProcess.signal.connect(self.writeText)
            self.validateProcess.finished.connect(self.finishedValidate)

            self.updateProcess = UpdateProcess()
            self.updateProcess.signal.connect(self.updateTable)
            self.updateProcess.start()

            # self.iface.messageBar().pushMessage("Executar validações.")
            self.writeText("\tA executar validações ...\n")
            self.validateProcess.start()

            self.buttonBox.button(QDialogButtonBox.StandardButton.Cancel).setText("Cancelar")
            self.buttonBox.button(QDialogButtonBox.StandardButton.Cancel).setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DialogDiscardButton))
            self.buttonBox.button(QDialogButtonBox.StandardButton.Ok).setEnabled(False)
            self.createProcess = None
        elif self.createProcess is not None:
            self.buttonBox.button(QDialogButtonBox.StandardButton.Cancel).setText("Fechar")
            self.buttonBox.button(QDialogButtonBox.StandardButton.Cancel).setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DialogCancelButton))
            self.buttonBox.button(QDialogButtonBox.StandardButton.Ok).setEnabled(True)
            self.progressBar.setVisible(False)
            self.createProcess = None

    def finishedReset(self):
        if self.resetProcess is not None:
            self.resetProcess = None

        self.baseSetup = False
        self.ruleSetup = False
        self.isRunning = False

        self.testValidationRules()


    @pyqtSlot('PyQt_PyObject', 'PyQt_PyObject', 'PyQt_PyObject', 'PyQt_PyObject', 'PyQt_PyObject', name='addLayer')
    def addLayer(self, group, layerDef, layerName, layerStyle="default", pos=-1):
        # self.iface.messageBar().pushMessage("Adicionar camada '" + layerName + "'")
        root = QgsProject.instance().layerTreeRoot()
        layerGroup = root.findGroup("DGT Recart - Erros Validação")
        if not layerGroup:
            layerGroup = root.insertGroup(0, "DGT Recart - Erros Validação")

        treeGroup = layerGroup.findGroup(group)
        if not treeGroup:
            treeGroup = layerGroup.insertGroup(pos, group)

        qlayer = QgsVectorLayer(layerDef, layerName, "postgres")
        qstyles = QgsStyle.defaultStyle()
        style = qstyles.symbol(layerStyle)

        if style is not None:
            qlayer.renderer().setSymbol(style)
            qlayer.triggerRepaint()

        QgsProject.instance().addMapLayer(qlayer, False)
        treeGroup.addLayer(qlayer)
        iface.layerTreeView().refreshLayerSymbology(qlayer.id())

    def reset(self):
        res = QMessageBox.question(self,'', "Tem a cereteza que quer remover os esquemas, as tabelas e as funções de validação?", QMessageBox.Yes | QMessageBox.No)

        if res == QMessageBox.Yes:
            self.writeText('[Aviso] Apaga os esquemas validation, errors e remove funções e procedimentos')

            # conString = qgis_configs.getConnString(self, self.getConnection())
            schema = str(self.schemaName.currentText())

            srsid = self.mQgsProjectionSelectionWidget.crs()
            self.writeText( 'Validar com o SRS {}'.format( srsid.postgisSrid() ) )
            self.srsid = srsid.postgisSrid()

            valid3d = True #self.checkBox.isChecked()

            self.resetProcess = ResetProcess(self.conString, schema, valid3d, self.srsid )

            self.resetProcess.signal.connect(self.writeText)
            self.resetProcess.finished.connect(self.finishedReset)

            # self.iface.messageBar().pushMessage("Criar estrutura de validação.")
            self.writeText("\tA apagar a estrutura de validação e erros anteriores...")
            self.isRunning = True
            self.resetProcess.start()

    def process(self):
        # carregou em OK
        self.tabWidget.setCurrentIndex(1)

        if self.testValidProcessing() and not self.isRunning:
            self.writeText("Validar base de dados...")
            self.progressBar.setVisible(True)

            # conString = qgis_configs.getConnString(self, self.getConnection())
            schema = str(self.schemaName.currentText())

            srsid = self.mQgsProjectionSelectionWidget.crs()
            self.writeText( 'Validar com o SRS {}'.format( srsid.postgisSrid() ) )
            self.srsid = srsid.postgisSrid()

            valid3d = True #self.checkBox.isChecked()

            self.createProcess = CreateProcess(self.conString, schema, valid3d, self.srsid, self.vrs, self.baseSetup, self.pgutils)

            self.createProcess.signal.connect(self.writeText)
            self.createProcess.finished.connect(self.finishedCreate)

            # self.iface.messageBar().pushMessage("Criar estrutura de validação.")
            self.writeText("\tA criar estrutura de validação ...")
            self.isRunning = True
            self.createProcess.start()
            self.buttonBox.button(QDialogButtonBox.StandardButton.Cancel).setText("Cancelar")
            self.buttonBox.button(QDialogButtonBox.StandardButton.Cancel).setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DialogDiscardButton))
            self.buttonBox.button(QDialogButtonBox.StandardButton.Ok).setEnabled(False)
        else:
            self.writeText('[Aviso] Configuração inválida')


class UpdateProcess(QThread):
    signal = pyqtSignal()

    def __init__(self):
        QThread.__init__(self)
        self.stop = False
        self.updated = False

    def setStop(self, state):
        self.stop = state

    def setUpdated(self, state):
        self.updated = state

    def run(self):
        try:
            while not self.stop:
                time.sleep(10)
                if not self.updated:
                    self.updated = True
                    self.signal.emit()
        except Exception as e:
            self.write("[Erro 8]")
            self.write(("\tException: {}".format(e)))


class AddLayersProcess(QThread):
    signal = pyqtSignal('PyQt_PyObject')
    addLayer = pyqtSignal('PyQt_PyObject', 'PyQt_PyObject', 'PyQt_PyObject',
                          'PyQt_PyObject', 'PyQt_PyObject')

    def __init__(self, conn, schema, srsid):
        QThread.__init__(self)
        self.conn = conn
        self.schema = schema
        self.srsid = srsid
        self.pgutils = PostgisUtils(self, conn)

    def trnl(self, text):
        tk = {
            'POINT': 'Ponto', 'POLYGON': 'Polígono',
            'LINESTRING': 'Linha'
        }
        return tk[text]

    def write(self, text):
        times = datetime.now()
        formated = times.strftime("%Y-%m-%d %H:%M:%S")
        self.signal.emit('{} {}'.format(formated, text))

    def run(self):
        self.actconn = self.pgutils.get_or_create_connection()
        try:
            tables = self.pgutils.run_query_with_conn(self.actconn,
                'WITH tbl AS (\
	                SELECT Table_Schema, Table_Name FROM information_schema.Tables \
	                WHERE Table_Schema IN (\'errors\')\
                ),\
                cnts as (\
	                SELECT Table_Name,\
                        (xpath(\'/row/c/text()\', query_to_xml(format(\
                        \'SELECT count(*) AS c FROM %I.%I\', Table_Schema, Table_Name\
                ), FALSE, TRUE, \'\')))[1]::text::int AS Records_Count \
	                FROM tbl\
                ) select Table_Name from cnts where Records_Count > 0')

            if ( tables ):
                for tb in tables:
                    ts = re.search(r'([a-z0-9_]+)_rg|([a-z0-9_]+)_re|([a-z0-9_]+)_ra|([a-z0-9_]+)_pq', tb[0])
                    slayer = None
                    if ts.group(1) is not None:
                        slayer = ts.group(1)
                    elif ts.group(2) is not None:
                        slayer = ts.group(2)
                    elif ts.group(3) is not None:
                        slayer = ts.group(3)
                    elif ts.group(4) is not None:
                        slayer = ts.group(4)
                    else:
                        print('-----')
                        print(tb[0])

                    if slayer is not None:
                        if len(displayList[slayer]["geom"]) > 0:
                            for gt in displayList[slayer]["geom"]:
                                ln = tb[0] if len(
                                    displayList[slayer]["geom"]) == 1 else tb[0] + " (" + self.trnl(gt) + ")"
                                con = self.conn
                                con = con + " srid=" + str(self.srsid) + " type=" + gt
                                con = con + " table='errors'.'" + \
                                    tb[0] + "' (geometria) sql="
                                self.addLayer.emit(
                                    displayList[slayer]["name"], con, ln, slayer, displayList[slayer]["index"])
                        else:
                            con = self.conn
                            con = con + " table='errors'.'" + tb[0] + "'"
                            self.addLayer.emit(
                                displayList[slayer]["name"], con, tb[0], slayer, displayList[slayer]["index"])

        except Exception as e:
            self.write("[Erro 9]")
            self.write(("\tException: {}".format(e)))


class ResetProcess(QThread):
    signal = pyqtSignal('PyQt_PyObject')

    def __init__(self, conn, schema, valid3d, srsid):
        QThread.__init__(self)

        self.conn = conn
        self.schema = schema
        self.valid3d = valid3d
        self.srsid = srsid

        self.bp = os.path.dirname(os.path.realpath(__file__))

        self.cancel = False

        self.pgutils = PostgisUtils(self, conn)

        self.actconn = None

    def write(self, text):
        self.signal.emit(text)

    def setCancel(self, state):
        self.cancel = state

        if state is True and self.actconn is not None:
            try:
                self.actconn.cancel()
                self.write("\t [Aviso] Operação cancelada")
            except Exception as e:
                self.write(e)
                # self.actconn.close()
                # self.actconn = None

    def run(self):
        try:
            file = None

            with open(self.bp + '/validation_reset.sql', 'r', encoding='utf-8') as f:
                cnt = f.read()
            cnt = re.sub(r"{schema}", self.schema, cnt)
            cnt = re.sub(r", 3763", ', ' + str(self.srsid), cnt)

            self.actconn = self.pgutils.get_or_create_connection()
            self.pgutils.run_query_with_conn(self.actconn, cnt, None, True)

            if file is not None:
                file.close()
        except Exception as e:
            if not self.cancel:
                self.write("[Erro 12]")
                self.write(("\tException: {}".format(e)))


class CreateProcess(QThread):
    signal = pyqtSignal('PyQt_PyObject')

    def __init__(self, conn, schema, valid3d, srsid, vrs, baseSetup=False, pgutils=None):
        QThread.__init__(self)

        self.conn = conn
        self.schema = schema
        self.valid3d = valid3d
        self.srsid = srsid
        
        self.baseSetup = baseSetup
        self.success = False

        self.bp = os.path.dirname(os.path.realpath(__file__))

        self.cancel = False

        self.pgutils = pgutils if pgutils is not None else PostgisUtils(self, conn)

        self.actconn = None
        self.vrs = vrs

    def write(self, text):
        self.signal.emit(text)

    def setCancel(self, state):
        self.cancel = state

        if state is True and self.actconn is not None:
            try:
                self.actconn.cancel()
                self.write("\t [Aviso] Operação cancelada")
            except Exception as e:
                self.write(e)
                # self.actconn.close()
                # self.actconn = None

    def run(self):
        try:
            self.actconn = self.pgutils.get_or_create_connection()

            # test database version
            # finddbquery = 'select count(*) from {schema}.valor_construcao_linear;'
            # cnt = re.sub(r"{schema}", self.schema, finddbquery)
            # res = self.pgutils.run_query_with_conn(self.actconn, cnt, None, False)
            # if res and len(res) > 0 and res[0][0] == 9:
            #     self.vrs = 'v1.1.2'
            # elif res and len(res) > 0 and res[0][0] == 11:
            #     self.vrs = 'v2.0.1'

            self.write("\tBase de dados com versão " + self.vrs)

            if self.baseSetup is not True:
                if ( len([x for x in self.pgutils.permissions.values() if 'createschema' in x and x['createschema']]) > 0 ):
                    # self.write("\t[Info] Com permissões para criar o esquema de validação.")
                    file = None
                    # if self.valid3d is True:
                    with open(self.bp + '/validation_setup.sql', 'r', encoding='utf-8') as f:
                        cnt = f.read()
                    cnt = re.sub(r"{schema}", self.schema, cnt)
                    cnt = re.sub(r", 3763", ', ' + str(self.srsid), cnt)

                    self.pgutils.run_query_with_conn(self.actconn, cnt, None, True)
                    # else:
                    #     file = open(self.bp + '/validation_setup_no3d.sql', "r", encoding='utf-8')
                    #     cnt = file.read()
                    #     cnt = re.sub(r"{schema}", self.schema, cnt)
                    #     cnt = re.sub(r", 3763", ', ' + str(self.srsid), cnt)

                    #     self.pgutils.run_query_with_conn(self.actconn, cnt, None, True)

                    if file is not None:
                        file.close()
                    self.success = True
                else:
                    self.write("\t[Erro] Sem permissões para criar o esquema de validação.")
        except Exception as e:
            if not self.cancel:
                self.write("[Erro 10]")
                self.write(("\tException: {}".format(e)))


class ValidateProcess(QThread):
    signal = pyqtSignal('PyQt_PyObject')

    def __init__(self, conn, schema, ndd1, vrs, is_sections=False, areaTable=None, args=None, fltrValue=None, pgutils=None):
        QThread.__init__(self)

        self.conn = conn
        self.schema = schema
        self.ndd1 = ndd1
        self.vrs = vrs
        
        self.structure_errors = []
        self.value_list_errors = []
        
        self.is_sections = is_sections
        self.areaTable = areaTable
        self.args = args if args is not None else {}
        self.fltrValue = fltrValue

        self.pgutils = pgutils if pgutils is not None else PostgisUtils(self, conn)

        self.actconn = None

        self.cancel = False

    def setCancel(self, state):
        self.cancel = state

        if state is True and self.actconn is not None:
            try:
                self.actconn.cancel()
                self.write("\t [Aviso] Operação cancelada")
            except Exception as e:
                self.write(e)
                # self.actconn.close()
                # self.actconn = None

    def write(self, text):
        self.signal.emit(text)

    def run(self):
        try:
            if 'validation' not in self.pgutils.permissions or ('validation' in self.pgutils.permissions
                    and self.pgutils.permissions['validation']['create'] is not True):
                self.write("\t[Erro] Sem permissões para executar as validações.")
                return

            self.actconn = self.pgutils.get_or_create_connection()

            validated = {}
            interrupt = False

            # validate values
            vndd = '1' if self.ndd1 == 'NdD1' else '2'
            res = self.pgutils.run_query_with_conn(self.actconn,
                            'select validation.atualiza_consistencia_valores_report(\'{}\', \'{}\');'.format(vndd, self.vrs))

            # validate structure
            base_dir = os.path.dirname(os.path.realpath(__file__))+'/convert/base/'+self.vrs
            base_files = [os.path.join(base_dir, f) for f in os.listdir(base_dir) if os.path.isfile(
                os.path.join(base_dir, f)) and f.lower().endswith('.json')]
            for bfile in base_files:
                try:
                    if os.path.basename(bfile) == 'relacoes.json':
                        continue
                    with open(bfile, encoding='utf-8') as base_file:
                        bfp = json.load(base_file)

                        objecto = bfp['objecto']
                        ccname = re.sub(r'(?<!^)(?=[A-Z][a-z])|(?=[A-Z]{3,})',
                                        '_', objecto['objeto']).lower()

                        campos = []
                        for attr in [r for r in objecto['Atributos'] if r['Multip.'] != '[1..*]' and r['Multip.'] != '[0..*]']:
                            attr['Atributo'] = re.sub(
                                r'iD', 'id', attr['Atributo'])
                            attr['Atributo'] = re.sub(
                                r'LAS', 'Las', attr['Atributo'])
                            attr['Atributo'] = re.sub(
                                r'valorElementoAssociadoPGQ', 'valor_elemento_associado_pgq', attr['Atributo'])
                            attr['Atributo'] = re.sub(
                                r'XY', 'Xy', attr['Atributo'])
                            attr['Atributo'] = re.sub(
                                r'datahomologacao', 'data_homologacao', attr['Atributo'])
                            attr['Atributo'] = re.sub(
                                r'nomeDoProdutor', 'nome_produtor', attr['Atributo'])
                            attr['Atributo'] = re.sub(
                                r'nomeDoProprietario', 'nome_proprietario', attr['Atributo'])
                            campos.append({
                                'nome': re.sub(r'(?<!^)(?=[A-Z])', '_', attr['Atributo']).lower(),
                                'tipo': attr['Tipo']
                            })

                        camposFrmt = json.dumps([x['nome'] for x in campos])
                        res = self.pgutils.run_query_with_conn(self.actconn,
                            'select validation.validate_table_columns(\'{}\', \'{}\');'.format(ccname, camposFrmt))
                        if res and len(res) > 0 and res[0][0] == False:
                            self.structure_errors.append([ccname, ' | '.join([x['nome'] for x in campos])])
                            interrupt = True
                            raise Exception(
                                "A tabela {} não tem os campos esperados:\n\t{}\nFuncionamento correto das validações não está assegurado.".format(ccname, camposFrmt))

                        for lista in objecto['listas de códigos']:
                            ltnome = re.sub(r'(?<!^)(?=[A-Z])', '_', lista['nome']).lower()
                            valores = json.dumps([{'identificador': val['Valores'], 'descricao': val['Descrição'].replace("'", "''''")} for val in lista['valores']], ensure_ascii=False)

                            if ltnome in validated:
                                continue
                            validated[ltnome] = True

                            res = self.pgutils.run_query_with_conn(self.actconn,
                                'select validation.validate_table_rows(\'{}\', \'{}\');'.format(ltnome, valores))
                            if res and len(res) > 0 and res[0][0] != []:
                                for err in res[0][0]:
                                    self.value_list_errors.append([ltnome, err['identificador'], err['descricao']])
                                interrupt = True
                                raise Exception(
                                    "A lista de valores {} não tem os valores esperados para as seguintes linhas:\n\t{}".format(ltnome, res[0][0]))
                except Exception as e:
                    self.write(
                        "Erro ao validar estrutura base.\n" + str(e))

            if interrupt:
                self.write("[Erro] Estrutura base inválida")
                # return
            else:
                self.write("\tEstrutura base validada")

            rules_table = "validation.rules" if not self.is_sections.isChecked() else "validation.rules_area"
            ndt = 'true' if self.ndd1 == 'NdD1' else 'false'
            sections = None

            fltr = 'true'

            if self.fltrValue is not None and self.fltrValue != '':
                fltr = self.fltrValue

            if not self.is_sections.isChecked():
                self.pgutils.run_query_with_conn(self.actconn,
                    "update validation.rules set total = 0, good = 0, bad = 0 \
                        where '{}' =any(versoes) and run=true;".format(self.vrs))
            else:
                sections = self.pgutils.run_query_with_conn(self.actconn,
                    "select identificador from {} where {};".format(self.areaTable, fltr))

            rules = self.pgutils.run_query_with_conn(self.actconn,
                "select code, name from {} \
                    where '{}' =any(versoes) and run=true\
                    order by dorder asc;".format(rules_table, self.vrs))

            i = 1
            l = 0
            if ( rules ):
                l = len(rules)
            if l > 0:
                # self.actconn = self.pgutils.get_connection()

                for r in rules:
                    if self.cancel:
                        break

                    if not self.is_sections.isChecked():
                        self.write("\tA executar validação '" + r[0] + " " + r[1] + "' (" + str(i) + " de " + str(l) + ")")
                        self.pgutils.run_query_with_conn(self.actconn, "call validation.do_validation("+ ndt + ", '" + self.vrs + "', '" + r[0] + "', '" + json.dumps(self.args) + "');")
                    else:
                        s = 1
                        for sec in sections:
                            if self.cancel:
                                break
                            self.write("\tA executar validação '" + r[0] + " " + r[1] + "' (" + str(i) + " de " + str(l) + " - secção " + str(s) + " de " + str(len(sections)) + ")")
                            # print("call validation.do_validation("+ ndt + ", '" + self.vrs + "', '" + self.areaTable + "', '" + r[0] + "', '" + sec[0] + "', '" + json.dumps(self.args) + "');")
                            self.pgutils.run_query_with_conn(self.actconn, "call validation.do_validation("+ ndt + ", '" + self.vrs + "', '" + self.areaTable + "', '" + r[0] + "', '" + sec[0] + "', '" + json.dumps(self.args) + "');")
                            s = s + 1
                    i = i + 1

            #     self.actconn.close()
            # self.actconn = None
            if self.cancel:
                self.write("\t [Aviso] Operação cancelada")
                return

            report_table = "validation.rules_area_report_view" if self.is_sections.isChecked() else "validation.rules"
            report = self.pgutils.run_query_with_conn(self.actconn,
                "select code, name, total, good, bad from {} \
                    where '{}' =any(versoes) and run=true\
                    order by dorder asc;".format(report_table, self.vrs))

            if report:
                self.write("\n\tSumário:")
                for line in report:
                    text = "\tValidada a regra '" + \
                        str(line[0]) + " - " + str(line[1]) + "'\t"
                    text = text + "\n\t\tSem erros detetados." if (
                        line[2] == line[3]) else text + "\n\t\tDetetados " + str(line[4]) + " erros."
                    self.write(text)

            # SELECT f_table_name, f_geometry_column, "type" FROM geometry_columns WHERE f_table_schema = 'errors';
            tables = self.pgutils.run_query_with_conn(self.actconn,
                'WITH tbl AS (\
	                SELECT Table_Schema, Table_Name FROM information_schema.Tables \
	                WHERE Table_Schema IN (\'errors\')\
                ),\
                cnts as (\
	                SELECT Table_Name,\
                        (xpath(\'/row/c/text()\', query_to_xml(format(\
                        \'SELECT count(*) AS c FROM %I.%I\', Table_Schema, Table_Name\
                ), FALSE, TRUE, \'\')))[1]::text::int AS Records_Count \
	                FROM tbl\
                ) select Table_Name from cnts where Records_Count > 0')
            if ( tables ):
                if len(tables) > 0:
                    self.write(
                        "\n\t[Aviso] Detetados erros na validação. A adicionar camadas com erros...")
            else:
                self.write(
                    "\t[Sucesso] Base de dados validada. Não foram detetados erros.")

            self.pgutils.run_query_with_conn(self.actconn, "update validation.rules set run = false \
                where '{}' =any(versoes);".format(self.vrs))
            self.pgutils.run_query_with_conn(self.actconn, "update validation.rules_area set run = false \
                where '{}' =any(versoes);".format(self.vrs))
        except Exception as e:
            if not self.cancel:
                self.write("[Erro 11]")
                self.write(("\tException: {}".format(e)))
