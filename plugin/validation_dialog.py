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
import re

from datetime import datetime

from PyQt5 import uic
from PyQt5.QtWidgets import QDialog, QDialogButtonBox, QHeaderView, QCheckBox, QStyle
from PyQt5.QtCore import Qt, QThread, pyqtSlot, pyqtSignal
from PyQt5.QtGui import QStandardItemModel, QStandardItem, QFont

from qgis.core import QgsProject, QgsVectorLayer, QgsStyle, QgsPrintLayout, QgsLayoutExporter, QgsLayoutItem, QgsLayoutItemTextTable, QgsLayoutTableColumn, QgsLayoutFrame, QgsLayoutSize, QgsLayoutPoint, QgsUnitTypes, QgsLayoutItemPage, QgsLayoutItemLabel
from qgis.utils import iface

from psycopg2 import OperationalError

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
        self.setupUi(self)

        self.iface = iface
        self.buttonBox.button(
            QDialogButtonBox.Ok).clicked.connect(self.process)

        self.comboBox.addItems(['NdD1', 'NdD2'])
        self.versaocomboBox.addItems(['V 1.1', 'V 1.1.1', 'V 1.1.2'])

        self.validateProcess = None
        self.createProcess = None

        self.pgutils = None
        self.ruleSetup = False

    def showEvent(self, event):
        super(ValidationDialog, self).showEvent(event)

        self.progressBar.setVisible(False)
        self.createProcess = None
        self.updateProcess = None

        if not self.initialized:
            self.buttonBox.button(QDialogButtonBox.Cancel).setText("Fechar")
            self.buttonBox.button(QDialogButtonBox.Cancel).setIcon(self.style().standardIcon(QStyle.SP_DialogCancelButton))
            self.buttonBox.button(QDialogButtonBox.Ok).setText("Validar")
            self.buttonBox.button(QDialogButtonBox.Ok).setIcon(self.style().standardIcon(QStyle.SP_DialogOkButton))
            self.buttonBox.button(QDialogButtonBox.Ok).setEnabled(True)

            self.tableView.horizontalHeader().setSectionResizeMode(QHeaderView.Interactive)
            self.tableView.horizontalHeader().setStretchLastSection(True)
            self.tableView.setVisible(False)

            self.fillDataSources()

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
            self.buttonBox.button(QDialogButtonBox.Cancel).setText("Fechar")
            self.buttonBox.button(QDialogButtonBox.Cancel).setIcon(self.style().standardIcon(QStyle.SP_DialogCancelButton))
            self.buttonBox.button(QDialogButtonBox.Ok).setEnabled(True)
            self.isRunning = False
        else:
            self.plainTextEdit.clear()
            super(ValidationDialog, self).reject()

    @pyqtSlot('PyQt_PyObject', name='writeText')
    def writeText(self, text):
        self.plainTextEdit.appendPlainText(text)

    def getConnection(self):
        return self.connCombo.currentText()

    def fillDataSources(self):
        self.connCombo.clear()
        dblist = qgis_configs.listDataSources()
        firstRow = 'Escolher conexão...' if len(
            dblist) > 0 else 'Sem conexões disponíveis'
        secondRow = 'Atualizar conexões...'
        self.connCombo.addItems([firstRow, secondRow] + dblist)

    def validate3dChange(self, state):
        if state is False and self.ruleSetup:
            try:
                self.pgutils.run_query(
                    "update validation.rules set run = false where code ilike 're3_2' or code ilike 'rg_4' or code ilike 'rg_4_1' or code ilike 'rg_4_2';")
                self.updateTable()
            except Exception as e:
                self.writeText("[Erro]")
                self.writeText(("\tException: {}".format(e)))

    def validateAllChange(self, state):
        if state is True and self.ruleSetup:
            try:
                self.pgutils.run_query(
                    "update validation.rules set run = true;")
                self.updateTable()
                self.checkBox.setChecked(True)
            except Exception as e:
                self.writeText("[Erro]")
                self.writeText(("\tException: {}".format(e)))        
        if state is False and self.ruleSetup:
            try:
                self.pgutils.run_query(
                    "update validation.rules set run = false;")
                self.updateTable()
                self.checkBox.setChecked(False)
            except Exception as e:
                self.writeText("[Erro]")
                self.writeText(("\tException: {}".format(e)))

    def setRuleState(self, state):
        rcode = self.sender().property("code")
        rstate = 'true' if state else 'false'

        try:
            self.pgutils.run_query("update validation.rules set run = " +
                                   rstate + " where code ilike '"+str(rcode)+"';")

            if (rcode == 're3_2' or rcode == 'rg_4' or rcode == 'rg_4_1' or rcode == 'rg_4_2') and state is True:
                self.checkBox.setChecked(True)
        except Exception as e:
            self.writeText("[Erro]")
            self.writeText(("\tException: {}".format(e)))

    def updateTable(self):
        try:
            report = self.pgutils.run_query(
                "select code, name, total, good, bad, run from validation.rules\
                    order by substring(code from 1 for 2) desc,\
                        ((regexp_match(code, '^r(?:g_|e)([0-9]+)_*'))[1])::integer asc,\
                        coalesce(((regexp_match(code, '[0-9]+_([0-9]+)_*'))[1])::integer, 0) asc,\
                        coalesce(((regexp_match(code, '[0-9]+_[0-9]+_([0-9])_*'))[1])::integer, 0) asc;")

            model = self.tableView.model()
            rn = 0
            for row in report:
                model.item(rn, 0).setData(row[0], Qt.EditRole)
                model.item(rn, 1).setData(row[1], Qt.EditRole)
                model.item(rn, 2).setData(str(row[2]), Qt.EditRole)
                model.item(rn, 3).setData(str(row[3]), Qt.EditRole)
                model.item(rn, 4).setData(str(row[4]), Qt.EditRole)

                cb = self.tableView.indexWidget(model.index(rn, 5))
                state = row[5]
                cb.setChecked(state)

                rn = rn + 1

            if self.updateProcess is not None:
                self.updateProcess.setUpdated(False)
        except Exception as e:
            self.writeText("[Erro]")
            self.writeText(("\tException: {}".format(e)))

    def testValidationRules(self):
        try:
            report = self.pgutils.run_query(
                "select code, name, total, good, bad, run from validation.rules\
                    order by substring(code from 1 for 2) desc,\
                        ((regexp_match(code, '^r(?:g_|e)([0-9]+)_*'))[1])::integer asc,\
                        coalesce(((regexp_match(code, '[0-9]+_([0-9]+)_*'))[1])::integer, 0) asc,\
                        coalesce(((regexp_match(code, '[0-9]+_[0-9]+_([0-9])_*'))[1])::integer, 0) asc;")

            self.tableView.setVisible(True)
            self.pushButton.setVisible(False)

            model = self.tableView.model()
            if model is None or model.rowCount() == 0:
                model = QStandardItemModel()
                self.tableView.setModel(model)

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

            self.ruleSetup = True
            self.relButton.setEnabled(True)
        except Exception as e:
            print(e)
            self.ruleSetup = False
            self.relButton.setEnabled(False)
            self.tableView.setVisible(False)
            self.pushButton.setVisible(True)

    def changeConn(self, newConnName):
        if newConnName == 'Atualizar conexões...':
            self.fillDataSources()
            self.plainTextEdit.appendPlainText("Conexões Postgis atualizadas")
            self.connCombo.setCurrentIndex(0)
        else:
            if newConnName != 'Escolher conexão...' and newConnName != 'Sem conexões disponíveis' and newConnName != "":
                conString = qgis_configs.getConnString(self, newConnName)
                # self.plainTextEdit.appendPlainText(
                #     "New connection to: {0}\n".format(conString))
                self.pgutils = PostgisUtils(self, conString)
                try:
                    schemas = self.pgutils.read_db_schemas()
                    # self.plainTextEdit.appendPlainText(
                    #     "Schemas: {0}\n".format(','.join(schemas)))
                    self.schemaName.clear()
                    self.schemaName.addItems(schemas)

                    model = self.tableView.model()
                    if model is not None:
                        model.clear()

                    self.testValidationRules()
                except ValueError as error:
                    self.plainTextEdit.appendPlainText(
                        "[Erro]: {0}\n".format(error))

    def testValidProcessing(self):
        res = True
        con = self.getConnection()
        res = (res and True) if con != 'Escolher conexão...' and con != 'Sem conexões disponíveis' and con != "" else (
            res and False)
        res = res and self.ruleSetup

        return res

    def createTable(self, layout, offsetx, offsety, size, columns, rows):
        table = QgsLayoutItemTextTable(layout)
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
        if not self.ruleSetup:
            self.writeText("[Aviso] Não é possível imprimir relatório")
            return
        try:
            summary = self.pgutils.run_query(
                "select code, name, total, good, bad from validation.rules\
                    order by substring(code from 1 for 2) desc,\
                        ((regexp_match(code, '^r(?:g_|e)([0-9]+)_*'))[1])::integer asc,\
                        coalesce(((regexp_match(code, '[0-9]+_([0-9]+)_*'))[1])::integer, 0) asc,\
                        coalesce(((regexp_match(code, '[0-9]+_[0-9]+_([0-9])_*'))[1])::integer, 0) asc;")

            rq = "SELECT (REGEXP_MATCHES(relname, '([a-z_]+)_rg|([a-z_]+)_re'))[1] as objeto1, (REGEXP_MATCHES(relname, '([a-z_]+)_rg|([a-z_]+)_re'))[2] as objeto2,"
            rq = rq + " (REGEXP_MATCHES(relname, '[a-z_]+_(rg[0-9_]*)|[a-z_]+_(re[0-9_]*)'))[1] as codigo1, (REGEXP_MATCHES(relname, '[a-z_]+_(rg[0-9_]*)|[a-z_]+_(re[0-9_]*)'))[2] as codigo2, n_live_tup"
            rq = rq + " FROM pg_stat_user_tables where schemaname = 'errors' and n_live_tup > 0 ORDER BY codigo1, codigo2, n_live_tup DESC;"
            report = self.pgutils.run_query(rq)

            times = datetime.now()
            footnote = times.strftime("%Y-%m-%d %H:%M:%S") +\
                " | Recart " + self.versaocomboBox.currentText() + " | " + self.comboBox.currentText()

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
                270, 210), cols, summary[25:])

            time = QgsLayoutItemLabel(layout)
            time.setText(footnote)
            time.setFont(QFont('Arial', 10, 25))
            time.adjustSizeToText()
            time.attemptMove(QgsLayoutPoint(8, 220+page.pageSize().height()-8))
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

                tabOff = 420
                for thm in sorted(themes):
                    npage = QgsLayoutItemPage(layout)
                    npage.setPageSize('A4', QgsLayoutItemPage.Landscape)
                    pages.addPage(npage)

                    section = QgsLayoutItemLabel(layout)
                    section.setText('Erros no Tema ' + str(thm))
                    section.setFont(QFont('Arial', 14, 75))
                    section.adjustSizeToText()
                    section.attemptMove(QgsLayoutPoint(8, 30 + tabOff))
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

                    self.createTable(layout, 12, 30 + tabOff, QgsLayoutSize(270, 190),
                                    cols, themes[thm])

                    time = QgsLayoutItemLabel(layout)
                    time.setText(footnote)
                    time.setFont(QFont('Arial', 10, 25))
                    time.adjustSizeToText()
                    time.attemptMove(QgsLayoutPoint(8, 220+tabOff))
                    layout.addItem(time)

                    tabOff = tabOff + 220

            title = self.lineEdit.text() if self.lineEdit.text() else "report"
            filepath = os.getcwd() + "/" + self.sanitize_filename(title) + \
                times.strftime("%Y%m%d%H%M%S") + ".pdf"
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
            self.writeText("[Erro]")
            self.writeText(("\tException: {}".format(e)))

    def changeSchema(self):
        if self.ruleSetup:
            self.setupRules()

    def setupRules(self):
        self.bp = os.path.dirname(os.path.realpath(__file__))
        self.schema = str(self.schemaName.currentText())
        try:
            cnt = open(self.bp + '/validation_rules.sql', "r", encoding='utf-8').read()
            cnt = cnt.format(schema=self.schema)
            self.pgutils.run_query(cnt)
            # self.pgutils.run_file(bp + '/validation_rules.sql')
            self.testValidationRules()
        except Exception as e:
            self.writeText("[Erro]")
            self.writeText(("\tException: {}".format(e)))

    def finishedValidate(self):
        self.updateProcess.setStop(True)
        self.updateTable()
        self.buttonBox.button(QDialogButtonBox.Cancel).setText("Fechar")
        self.buttonBox.button(QDialogButtonBox.Cancel).setIcon(self.style().standardIcon(QStyle.SP_DialogCancelButton))

        if not self.validateProcess.cancel is True:
            conString = qgis_configs.getConnString(self, self.getConnection())
            self.schema = str(self.schemaName.currentText())

            self.addLayersProcess = AddLayersProcess(conString, self.schema)
            self.addLayersProcess.signal.connect(self.writeText)
            self.addLayersProcess.addLayer.connect(self.addLayer)
            self.addLayersProcess.finished.connect(self.finishedAddLayers)
            self.addLayersProcess.start()
        else:
            self.isRunning = False
            self.progressBar.setVisible(False)
            self.buttonBox.button(QDialogButtonBox.Ok).setEnabled(True)

        self.validateProcess = None

    def finishedAddLayers(self):
        self.isRunning = False
        self.progressBar.setVisible(False)
        self.buttonBox.button(QDialogButtonBox.Ok).setEnabled(True)

        self.writeText("Terminada a validação")

    def finishedCreate(self):
        if self.createProcess is not None and not self.createProcess.cancel is True:
            conString = qgis_configs.getConnString(self, self.getConnection())
            schema = str(self.schemaName.currentText())

            self.validateProcess = ValidateProcess(conString, schema, self.comboBox.currentText())

            self.validateProcess.signal.connect(self.writeText)
            self.validateProcess.finished.connect(self.finishedValidate)

            self.updateProcess = UpdateProcess()
            self.updateProcess.signal.connect(self.updateTable)
            self.updateProcess.start()

            # self.iface.messageBar().pushMessage("Executar validações.")
            self.writeText("\tA executar validações ...\n")
            self.validateProcess.start()

            self.buttonBox.button(QDialogButtonBox.Cancel).setText("Cancelar")
            self.buttonBox.button(QDialogButtonBox.Cancel).setIcon(self.style().standardIcon(QStyle.SP_DialogDiscardButton))
            self.buttonBox.button(QDialogButtonBox.Ok).setEnabled(False)
            self.createProcess = None
        elif self.createProcess is not None:
            self.buttonBox.button(QDialogButtonBox.Cancel).setText("Fechar")
            self.buttonBox.button(QDialogButtonBox.Cancel).setIcon(self.style().standardIcon(QStyle.SP_DialogCancelButton))
            self.buttonBox.button(QDialogButtonBox.Ok).setEnabled(True)
            self.progressBar.setVisible(False)
            self.createProcess = None

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

    def process(self):
        # carregou em OK
        if self.testValidProcessing() and not self.isRunning:
            self.writeText("Validar base de dados...")
            self.progressBar.setVisible(True)

            conString = qgis_configs.getConnString(self, self.getConnection())
            schema = str(self.schemaName.currentText())

            valid3d = self.checkBox.isChecked()

            self.createProcess = CreateProcess(conString, schema, valid3d)

            self.createProcess.signal.connect(self.writeText)
            self.createProcess.finished.connect(self.finishedCreate)

            # self.iface.messageBar().pushMessage("Criar estrutura de validação.")
            self.writeText("\tA criar estrutura de validação ...")
            self.isRunning = True
            self.createProcess.start()
            self.buttonBox.button(QDialogButtonBox.Cancel).setText("Cancelar")
            self.buttonBox.button(QDialogButtonBox.Cancel).setIcon(self.style().standardIcon(QStyle.SP_DialogDiscardButton))
            self.buttonBox.button(QDialogButtonBox.Ok).setEnabled(False)
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
            self.write("[Erro]")
            self.write(("\tException: {}".format(e)))


class AddLayersProcess(QThread):
    signal = pyqtSignal('PyQt_PyObject')
    addLayer = pyqtSignal('PyQt_PyObject', 'PyQt_PyObject', 'PyQt_PyObject',
                          'PyQt_PyObject', 'PyQt_PyObject')

    def __init__(self, conn, schema):
        QThread.__init__(self)
        self.conn = conn
        self.schema = schema
        self.pgutils = PostgisUtils(self, conn)

    def trnl(self, text):
        tk = {
            'POINT': 'Ponto', 'POLYGON': 'Polígono',
            'LINESTRING': 'Linha'
        }
        return tk[text]

    def run(self):
        try:
            tables = self.pgutils.run_query(
                'SELECT table_name FROM information_schema.tables WHERE table_schema = \'errors\'')

            for tb in tables:
                ts = re.search(r'([a-z_]+)_rg|([a-z_]+)_re', tb[0])
                slayer = None
                if ts.group(1) is not None:
                    slayer = ts.group(1)
                elif ts.group(2) is not None:
                    slayer = ts.group(2)
                else:
                    print('-----')
                    print(tb[0])

                if slayer is not None:
                    if len(displayList[slayer]["geom"]) > 0:
                        for gt in displayList[slayer]["geom"]:
                            ln = tb[0] if len(
                                displayList[slayer]["geom"]) == 1 else tb[0] + " (" + self.trnl(gt) + ")"
                            con = self.conn
                            con = con + " srid=3763 type=" + gt
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
            self.write("[Erro]")
            self.write(("\tException: {}".format(e)))


class CreateProcess(QThread):
    signal = pyqtSignal('PyQt_PyObject')

    def __init__(self, conn, schema, valid3d):
        QThread.__init__(self)

        self.conn = conn
        self.schema = schema
        self.valid3d = valid3d

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
                self.actconn.close()
                self.actconn = None

    def run(self):
        try:
            file = None
            if self.valid3d is True:
                file = open(self.bp + '/validation_setup.sql', "r", encoding='utf-8')
                cnt = file.read()
                cnt = cnt.format(schema=self.schema)

                self.actconn = self.pgutils.get_connection()
                self.pgutils.run_query_with_conn(self.actconn, cnt, None, True)
            else:
                file = open(self.bp + '/validation_setup_no3d.sql', "r", encoding='utf-8')
                cnt = file.read()
                cnt = cnt.format(schema=self.schema)

                self.actconn = self.pgutils.get_connection()
                self.pgutils.run_query_with_conn(self.actconn, cnt, None, True)

            if file is not None:
                file.close()
        except Exception as e:
            if not self.cancel:
                self.write("[Erro]")
                self.write(("\tException: {}".format(e)))


class ValidateProcess(QThread):
    signal = pyqtSignal('PyQt_PyObject')

    def __init__(self, conn, schema, ndd1):
        QThread.__init__(self)

        self.conn = conn
        self.schema = schema
        self.ndd1 = ndd1

        self.pgutils = PostgisUtils(self, conn)

        self.actconn = None

        self.cancel = False

    def setCancel(self, state):
        self.cancel = state

        if state is True and self.actconn is not None:
            try:
                self.actconn.cancel()
                self.write("\t [Aviso] Operação cancelada")
            except Exception as e:
                self.actconn.close()
                self.actconn = None

    def write(self, text):
        self.signal.emit(text)

    def run(self):
        try:
            self.pgutils.run_query(
                'update validation.rules set total = 0, good = 0, bad = 0;')

            ndt = 'true' if self.ndd1 == 'NdD1' else 'false'
            rules = self.pgutils.run_query(
                "select code, name from validation.rules where run=true\
                    order by substring(code from 1 for 2) desc,\
                        ((regexp_match(code, '^r(?:g_|e)([0-9]+)_*'))[1])::integer asc,\
                        coalesce(((regexp_match(code, '[0-9]+_([0-9]+)_*'))[1])::integer, 0) asc,\
                        coalesce(((regexp_match(code, '[0-9]+_[0-9]+_([0-9])_*'))[1])::integer, 0) asc;")

            i = 1
            l = len(rules)
            if l > 0:
                self.actconn = self.pgutils.get_connection()

            for r in rules:
                if self.cancel:
                    break

                self.write("\tA executar validação '" + r[0] + " " + r[1] + "' (" + str(i) + " de " + str(l) + ")")
                self.pgutils.run_query_with_conn(self.actconn, "call validation.do_validation("+ ndt + ", '" + r[0] + "');")
                i = i + 1

            self.actconn.close()
            self.actconn = None
            if self.cancel:
                self.write("\t [Aviso] Operação cancelada")
                return

            report = self.pgutils.run_query(
                "select code, name, total, good, bad from validation.rules where run=true\
                    order by substring(code from 1 for 2) desc,\
                        ((regexp_match(code, '^r(?:g_|e)([0-9]+)_*'))[1])::integer asc,\
                        coalesce(((regexp_match(code, '[0-9]+_([0-9]+)_*'))[1])::integer, 0) asc,\
                        coalesce(((regexp_match(code, '[0-9]+_[0-9]+_([0-9])_*'))[1])::integer, 0) asc;")

            self.write("\n\tSumário:")
            for line in report:
                text = "\tValidada a regra '" + \
                    str(line[0]) + " - " + str(line[1]) + "'\t"
                text = text + "\n\t\tSem erros detetados." if (
                    line[2] == line[3]) else text + "\n\t\tDetetados " + str(line[4]) + " erros."
                self.write(text)

            # SELECT f_table_name, f_geometry_column, "type" FROM geometry_columns WHERE f_table_schema = 'errors';
            tables = self.pgutils.run_query(
                'SELECT table_name FROM information_schema.tables WHERE table_schema = \'errors\'')

            if len(tables) > 0:
                self.write(
                    "\n\t[Aviso] Detetados erros na validação. A adicionar camadas com erros...")
            else:
                self.write(
                    "\t[Sucesso] Base de dados validada. Não foram detetados erros.")

            self.pgutils.run_query('update validation.rules set run = false;')
        except Exception as e:
            if not self.cancel:
                self.write("[Erro]")
                self.write(("\tException: {}".format(e)))
