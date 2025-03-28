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
import datetime
import math
import time
import json

from enum import Enum
from pathlib import Path

from PyQt5 import uic
from PyQt5.QtWidgets import QDialog, QProgressDialog, QMessageBox, QAbstractItemView
from PyQt5.QtCore import Qt, QThread, pyqtSlot, pyqtSignal, QVariant
from PyQt5.QtGui import QIntValidator, QStandardItemModel, QStandardItem

from qgis.core import QgsProject, QgsVectorLayer, QgsDataSourceUri, QgsStyle, QgsEditorWidgetSetup, QgsLayerTreeGroup, QgsLayerTreeLayer, QgsCoordinateReferenceSystem, QgsVectorLayerJoinInfo
from qgis.utils import iface

from qgis.PyQt.QtTest import QSignalSpy

from osgeo import gdal
from osgeo import ogr
from osgeo import osr

import re

from . import qgis_configs
from .postgis_helper import PostgisUtils
from .aux_export import displayList, recartStructure, fieldNameMap, joins

FORM_CLASS, _ = uic.loadUiType(os.path.join(
    os.path.dirname(__file__), 'ui/main_dialog.ui'))


class MainDialog(QDialog, FORM_CLASS):
    def __init__(self, iface, parent=None):
        super(MainDialog, self).__init__(parent)
        self.initialized = False
        self.setupUi(self)

        self.iface = iface
        self.treeView.setSelectionMode(QAbstractItemView.MultiSelection)
        self.exportFormat.addItems(
            ['Shapefile', 'GeoJSON', 'GeoPackage', 'Projeto QGIS'])
        self.exportEncoding.addItems(
            ['utf-8', 'iso-8859-1'])

        self.displayLayerList = displayList
        # para se adivinhar o CRS da fonte de dados
        self.srs = ''

    def showEvent(self, event):
        super(MainDialog, self).showEvent(event)

        self.progressBar.setVisible(False)

        if not self.initialized:
            self.fillDataSources()
            self.initialized = True

    def closeEvent(self, event):
        super(MainDialog, self).closeEvent(event)

    @pyqtSlot('PyQt_PyObject', name='writeText')
    def writeText(self, text):
        self.plainTextEdit.appendPlainText(text)

    @pyqtSlot('PyQt_PyObject', 'PyQt_PyObject', 'PyQt_PyObject', 'PyQt_PyObject', 'PyQt_PyObject', name='addLayer')
    def addLayer(self, group, layerDef, layerName, layerStyle="default", pos=-1):
        root = QgsProject.instance().layerTreeRoot()
        layerGroup = root.findGroup("DGT Recart")
        if not layerGroup:
            layerGroup = root.insertGroup(0, "DGT Recart")

        treeGroup = layerGroup.findGroup(group)
        if not treeGroup:
            treeGroup = layerGroup.insertGroup(pos, group)

        qlayer = QgsVectorLayer(layerDef, layerName, "postgres")
        # qstyles = QgsStyle.defaultStyle()
        # style = qstyles.symbol(layerStyle)

        # if style is not None:
        #     qlayer.renderer().setSymbol(style)
        #     qlayer.triggerRepaint()

        QgsProject.instance().addMapLayer(qlayer, False)
        treeGroup.addLayer(qlayer)
        iface.layerTreeView().refreshLayerSymbology(qlayer.id())

    def fillDataSources(self):
        self.connCombo.clear()
        dblist = qgis_configs.listDataSources()
        firstRow = 'Escolher conexão...' if len(
            dblist) > 0 else 'Sem conexões disponíveis'
        secondRow = 'Atualizar conexões...'
        self.connCombo.addItems([firstRow, secondRow] + dblist)

    def changeConn(self, newConnName):
        self.schemaName.clear()

        if newConnName == 'Atualizar conexões...':
            self.fillDataSources()
            self.plainTextEdit.appendPlainText("Conexões Postgis atualizadas")
            self.connCombo.setCurrentIndex(0)
        else:
            if newConnName != 'Escolher conexão...' and newConnName != 'Sem conexões disponíveis' and newConnName != "":
                conString = qgis_configs.getConnString(self, newConnName)
                # self.plainTextEdit.appendPlainText(
                #     "New connection to: {0}\n".format(conString))
                if conString is None:
                    self.plainTextEdit.appendPlainText(
                        "[Aviso] {0}\n".format("Conexão inválida"))
                    self.fillDataSources()
                    return

                utils = PostgisUtils(self, conString)
                try:
                    schemas = utils.read_db_schemas()
                    if not len(schemas) > 0:
                        self.plainTextEdit.appendPlainText(
                            "[Aviso] {0}\n".format("Conexão inválida"))
                        self.fillDataSources()
                        return

                    self.schemaName.addItems(schemas)
                except ValueError as error:
                    self.plainTextEdit.appendPlainText(
                        "[Erro]: {0}\n".format(error))

    def selectAll(self, state):
        if state != 0:
            self.treeView.expandAll()
            self.treeView.selectAll()

    def onChangeFormat(self, fmt):
        if fmt == 'Projeto QGIS':
            self.aliasCheckBox.setEnabled(False)
            self.mQgsFileWidget.setEnabled(False)
            self.exportEncoding.setEnabled(False)
        else:
            self.aliasCheckBox.setEnabled(True)
            self.mQgsFileWidget.setEnabled(True)
            self.exportEncoding.setEnabled(True)

    def doLoadLayers(self):
        conString = qgis_configs.getConnString(
            self, self.connCombo.currentText())
        schema = str(self.schemaName.currentText())

        if conString is None:
            self.plainTextEdit.appendPlainText(
                        "[Aviso] {0}\n".format("Ligação inválida"))
            return

        self.loadLayersProcess = LoadLayersProcess(conString, schema)

        self.loadLayersProcess.signal.connect(self.writeText)
        self.loadLayersProcess.finished.connect(self.finishedLoadLayers)

        self.iface.messageBar().pushMessage("Carregar camadas Recart.")
        self.loadLayersProcess.start()

    def finishedLoadLayers(self):
        try:
            self.dataSource = self.loadLayersProcess.dataSource
            self.fillLayerList(self.dataSource)

            crs = QgsCoordinateReferenceSystem("EPSG:" + self.srs)
            self.mQgsProjectionSelectionWidget.setCrs( crs )

        except AttributeError as e:
            print(e)
            self.plainTextEdit.appendPlainText(
                        "[Erro] {0}\n".format("Não foi possível carregar camadas"))

    def fillLayerList(self, dataSource):
        model = QStandardItemModel()
        model.setHorizontalHeaderItem(
            0, QStandardItem(re.sub(r"password=([^ ]*)", "", dataSource.GetDescription())))

        roots = {}
        for li in range(dataSource.GetLayerCount()):
            layer = dataSource.GetLayerByIndex(li)
            # feat = layer.GetNextFeature()

            if layer.GetName() in self.displayLayerList:
                item = QStandardItem(layer.GetName())

                # detetar o sistema de corrdenadas a partir de qualquer uma das camadas

                if layer.GetSpatialRef():
                    authid = layer.GetSpatialRef().GetAuthorityCode( 'PROJCS' )
                    if self.srs != authid:
                        self.srs = authid
                        self.writeText("Detetada camada {} com o sistema de coordenadas {}".format( layer.GetName(), authid ) )

                if self.displayLayerList[layer.GetName()]['name'] in roots:
                    roots[self.displayLayerList[layer.GetName()]['name']
                          ]['model'].appendRow(item)
                else:
                    nbase = QStandardItem(
                        self.displayLayerList[layer.GetName()]['name'])
                    nbase.setSelectable(False)
                    nbase.appendRow(item)
                    roots[self.displayLayerList[layer.GetName()]['name']] = {
                        'model': nbase, 'index': self.displayLayerList[layer.GetName()]['index']}

        found = False
        for br in sorted(roots, key=lambda item: roots[item]['index']):
            found = True
            model.appendRow(roots[br]['model'])

        self.treeView.setModel(model)
        # self.treeView.expandAll()
        if not found:
            self.writeText("[Aviso] Não foram encontradas camadas válidas")

    def doExportLayers(self):
        self.iface.messageBar().pushMessage("Exportar camadas.")
        self.writeText("A exportar camadas ...")
        self.progressBar.setVisible(True)

        srsid = self.mQgsProjectionSelectionWidget.crs()
        # self.writeText( 'Exportar no SRS {}'.format( srsid.authid() ) )
        self.writeText( 'Exportar no SRS {}'.format( srsid.postgisSrid() ) )

        outFormat = self.exportFormat.currentText()
        outEncoding = self.exportEncoding.currentText()
        layerList = []

        seli = self.treeView.selectionModel().selectedIndexes()
        for index in seli:
            name = index.data(Qt.DisplayRole)
            layerList.append(name)

        self.exportLayersProcess = ExportLayersProcess(
            self.loadLayersProcess.conString, self.loadLayersProcess.schema,
            self.dataSource, layerList, outFormat, outEncoding, self.mQgsFileWidget.filePath(), self.aliasCheckBox.isChecked(), 
            srsid.postgisSrid() )

        self.exportLayersProcess.signal.connect(self.writeText)
        self.exportLayersProcess.addLayer.connect(self.addLayer)
        self.exportLayersProcess.finished.connect(self.finishedExportLayers)

        self.exportLayersProcess.start()

    def get_group_layers(self, group):
        # print('- group: ' + group.name())
        for child in group.children():
            if isinstance(child, QgsLayerTreeGroup):
                # print('  - group: ' + child.name())
                self.get_group_layers(child)
            else:
                child.setCustomProperty("showFeatureCount", True)
                # print('  - layer: ' + child.name())

    def finishedExportLayers(self):
        self.progressBar.setVisible(False)

        if self.exportFormat.currentText() == 'Projeto QGIS':
            project = QgsProject.instance()
            manager = project.relationManager()
            relations = manager.relations()
            layers = QgsProject.instance().mapLayers()

            self.writeText('Aguarde a análise das relações, por favor...')
            rels = manager.discoverRelations( relations.values(), layers.values() )
            self.writeText( "Relações encontradas: {}".format( len(rels) ) )

            rel_names = {}
            for rel in rels:
                if rel.name() in rel_names:
                    rel_names[rel.name()] += 1
                    rel.setName(rel.name() + '_' + str(rel_names[rel.name()]))
                else:
                    rel_names[rel.name()] = 0
                # if rel.name().startswith('valor_zona'):
                manager.addRelation(rel)
                # print(rel.name(), rel.referencedLayer().name(), rel.referencingLayer().name())
                layer = rel.referencingLayer()
                fields = layer.fields()
                field = fields[ rel.referencingFields()[0] ]
                field_idx = fields.indexOf(field.name())
                config = {
                    'Relation': rel.id(),
                    'ShowOpenFormButton': False
                }
                widget_setup = QgsEditorWidgetSetup('RelationReference',config)
                layer.setEditorWidgetSetup(field_idx, widget_setup)
                # print( "Camada {} configurada com base na relação".format( layer.name() ) )

            for j in joins:
                slayers = QgsProject.instance().mapLayersByName(j)
                if slayers and len(slayers) > 0:
                    qlayer = slayers[0]
                    jls = QgsProject.instance().mapLayersByName(joins[j]['join_table'])
                    if jls and len(jls) > 0:
                        jl = jls[0]
                        jo = QgsVectorLayerJoinInfo()
                        jo.setJoinLayer(jl)
                        jo.setJoinFieldName(joins[j]['join_field'])
                        jo.setTargetFieldName(joins[j]['target_field'])
                        jo.setJoinFieldNamesSubset(joins[j]['joined_fields'])
                        jo.setUsingMemoryCache(joins[j]['memory_cache'])
                        jo.setPrefix(joins[j]['prefix'])

                        qlayer.addJoin(jo)

            self.writeText('Aguarde a contagem dos elementos em cada camada, por favor...')

            root = QgsProject.instance().layerTreeRoot()
            for child in root.children():
                if isinstance(child, QgsLayerTreeGroup):
                    # print ('- group: ' + child.name())
                    self.get_group_layers(child)
                elif isinstance(child, QgsLayerTreeLayer):
                    child.setCustomProperty("showFeatureCount", True)
                    # print ('- layer: ' + child.name())

            taGroupNode = root.findGroup( 'Tabelas Auxiliares' )
            if ( taGroupNode ):
                taGroupNode.setExpanded(False)

            self.writeText('Tarefas terminadas')


class LoadLayersProcess(QThread):
    signal = pyqtSignal('PyQt_PyObject')

    def __init__(self, conString, schema):
        QThread.__init__(self)

        self.conString = conString
        self.schema = schema

    def write(self, text):
        self.signal.emit(text)

    def run(self):
        try:
            self.write("A carregar camadas da fonte de dados...")
            # self.write(self.conString)
            gdal.UseExceptions()
            self.dataSource = gdal.OpenEx('PG:'+self.conString, gdal.OF_VECTOR, open_options=[
                'SCHEMAS='+self.schema, 'LIST_ALL_TABLES=YES'])
            if self.dataSource is None:
                raise ValueError('Não foi possível carregar a fonte de dados')

            self.write('[Sucesso] Camadas carregadas')
        except Exception as e:
            self.write("[Erro -1]")
            self.write(("\tException: {}".format(e)))


class ExportLayersProcess(QThread):
    signal = pyqtSignal('PyQt_PyObject')
    addLayer = pyqtSignal('PyQt_PyObject', 'PyQt_PyObject', 'PyQt_PyObject',
                          'PyQt_PyObject', 'PyQt_PyObject')

    def __init__(self, connection, schema, datasource, layerList, outFormat, outEncoding, outDir, exportAlias, srsid):
        QThread.__init__(self)

        self.conn = connection
        self.schema = schema
        self.datasource = datasource
        self.layerList = layerList
        self.outFormat = outFormat
        self.outEncoding = outEncoding
        self.outDir = outDir
        self.exportAlias = exportAlias
        self.exportSrsId = srsid

        if not self.outDir:
            self.outDir = str(Path.home())

        self.flatLayers = recartStructure
        self.fieldMap = fieldNameMap

    def write(self, text):
        self.signal.emit(text)

    def run(self):
        try:
            if self.outFormat == 'GeoPackage':
                self.exportGeoPackage()
            elif self.outFormat == 'GeoJSON':
                self.exportGeoJSON()
            elif self.outFormat == 'Shapefile':
                self.exportShapefile()
            elif self.outFormat == 'Projeto QGIS':
                self.exportQGISProject()
            else:
                raise ValueError('Formato de exportação desconhecido')

            self.write('Processo exportação terminado')
        except Exception as e:
            self.write("[Erro -2]")
            self.write(("\tException: {}".format(str(e))))

    def get_group_layers(self, group):
        # print('- group: ' + group.name())
        for child in group.children():
            if isinstance(child, QgsLayerTreeGroup):
                # print('  - group: ' + child.name())
                self.get_group_layers(child)
            else:
                child.setCustomProperty("showFeatureCount", True)
                # print('  - layer: ' + child.name())

    def exportQGISProject(self):
        exportedLayers = {}

        # qstyles = QgsStyle.defaultStyle()
        # before = qstyles.symbolNames()
        # qstyles.importXml('carttop.xml')
        # after = qstyles.symbolNames()
        # mystyles = list(set(after) - set(before))
        # for s in mystyles:
        #     qstyles.addFavorite(QgsStyle.StyleEntity.SymbolEntity, s)

        # Injetar layer_styles.sql na BD

        bp = os.path.dirname(os.path.realpath(__file__))
        try:
            with open(bp + '/convert/processing/layer_styles.sql', encoding='utf-8') as pp_file:
                pp_src = pp_file.read()
                styles = re.sub(r"{schema}", self.schema, pp_src)
                utils = PostgisUtils(self, self.conn)
                utils.run_query(styles)
        except Exception as e:
            self.write(
                'Erro a inserir os estilos em base de dados: \'' + str(e) + '\'')


        layer_was_added_spy = QSignalSpy(QgsProject.instance().layerWasAdded)
        # layers_added_spy = QSignalSpy(QgsProject.instance().layersAdded)

        nlayers = 0
        
        for slayer in self.layerList:
            if slayer not in exportedLayers:
                if len(displayList[slayer]["geom"]) > 0:
                    for gt in displayList[slayer]["geom"]:
                        ln = displayList[slayer]["alias"] if len(
                            displayList[slayer]["geom"]) == 1 else displayList[slayer]["alias"] + " (" + gt + ")"
                        con = self.conn
                        con = con + " srid=" + str(self.exportSrsId) + " type=" + gt
                        con = con + " table='" + self.schema + \
                            "'.'" + slayer + "' (geometria) sql="
                        self.addLayer.emit(
                            displayList[slayer]["name"], con, ln, slayer, displayList[slayer]["index"])
                        nlayers = nlayers + 1
                else:
                    con = self.conn
                    con = con + " table='" + self.schema + "'.'" + slayer + "'"
                    self.addLayer.emit(
                        displayList[slayer]["name"], con, displayList[slayer]["alias"], slayer, displayList[slayer]["index"])
                    nlayers = nlayers + 1

                exportedLayers[slayer] = 1
                self.write('[Sucesso] Camada \'' + slayer + '\' exportada')

                rTables = self.getRefTables(slayer)
                for tb in rTables:
                    if tb not in exportedLayers:
                        qlayer = self.conn + " table='" + self.schema + "'.'" + tb + "'"
                        self.addLayer.emit("Tabelas Auxiliares", qlayer, tb, "default", 0)
                        nlayers = nlayers + 1

                        exportedLayers[tb] = 1
                        self.write('\tTabela \'' + tb + '\' exportada')

        # Wait for loading all layers... 30 seg. maximum
        # self.write('Aguarde o carregamento das camadas, por favor...')
        # timeout = 30
        # while len(layer_was_added_spy) < nlayers and timeout > 0:
        #     timeout = timeout - 1
        #     time.sleep(1)

        # project = QgsProject.instance()
        # manager = project.relationManager()
        # relations = manager.relations()
        # layers = QgsProject.instance().mapLayers()

        # self.write('Aguarde a análise das relações, por favor...')
        # rels = manager.discoverRelations( relations.values(), layers.values() )
        # self.write( "Relações encontradas: {}".format( len(rels) ) )

        # for rel in rels:
        #     # if rel.name().startswith('valor_zona'):
        #     manager.addRelation(rel)
        #     # print(rel.name(), rel.referencedLayer().name(), rel.referencingLayer().name())
        #     layer = rel.referencingLayer()
        #     fields = layer.fields()
        #     field = fields[ rel.referencingFields()[0] ]
        #     field_idx = fields.indexOf(field.name())
        #     config = {
        #         'Relation': rel.id(),
        #         'ShowOpenFormButton': False
        #     }
        #     widget_setup = QgsEditorWidgetSetup('RelationReference',config)
        #     layer.setEditorWidgetSetup(field_idx, widget_setup)
        #     # print( "Camada {} configurada com base na relação".format( layer.name() ) )

        # self.write('Aguarde a contagem dos elementos em cada camada, por favor...')

        # root = QgsProject.instance().layerTreeRoot()
        # for child in root.children():
        #     if isinstance(child, QgsLayerTreeGroup):
        #         # print ('- group: ' + child.name())
        #         self.get_group_layers(child)
        #     elif isinstance(child, QgsLayerTreeLayer):
        #         child.setCustomProperty("showFeatureCount", True)
        #         # print ('- layer: ' + child.name())

        # taGroupNode = root.findGroup( 'Tabelas Auxiliares' )
        # taGroupNode.setExpanded(False)

    def exportGeoPackage(self):
        exportedLayers = {}
        driver = gdal.GetDriverByName('GPKG')
        outdata = driver.Create(
            self.outDir+'/export.gpkg', 0, 0, 0, gdal.GDT_Unknown)

        self.write( 'A exportar para {}'.format( self.outDir+'/export.gpkg' ) )

        for slayer in self.layerList:
            if slayer not in exportedLayers:
                self.write( 'A exportar a camada {}'.format( slayer ) )
                layertogo = self.datasource.GetLayerByName(slayer)
                if layertogo:
                    outdata.CopyLayer( layertogo, slayer)
                    exportedLayers[slayer] = 1
                    rTables = self.getRefTables(slayer)
                    for tb in rTables:
                        if tb not in exportedLayers:
                            self.write( 'A exportar a tabela {}'.format( tb ) )
                            tabletogo = self.datasource.GetLayerByName(tb)
                            if tabletogo:
                                outdata.CopyLayer( tabletogo, tb)
                                exportedLayers[tb] = 1
                #             else:
                #                 self.write( 'Erro a exportar a tabela {}'.format( tb ) )
                # else:
                #     self.write( 'Erro a exportar a camada {}'.format( slayer ) )

    def getRefTables(self, layer):
        aux = []
        if layer in self.flatLayers:
            for l in self.flatLayers[layer]['ligs']:
                if l[0] is not None:
                    aux.append(l[0])
                    if l[1] is not None:
                        aux.append(l[1])
                else:
                    aux.append(l[1][:-3])

                for rf in l[3]:
                    aux.append(rf[0])
            for r in self.flatLayers[layer]['refs']:
                aux.append(r)

        return aux

    def getLayerSQL(self, layer):
        sql = ''
        if layer in self.flatLayers:
            sql = 'select ' + \
                ', '.join(
                    [str(layer + '.')+f for f in self.flatLayers[layer]['fields']])

            for ref in self.flatLayers[layer]['refs']:
                sql += ', string_agg(distinct ' + ref + \
                    '.descricao, \'|\') as "' + ref + '"'

            for lig in self.flatLayers[layer]['ligs']:
                if lig[1] in self.layerList or lig[2] is True:
                    lk = lig[1] if lig[0] is not None else lig[1][:-3]
                    if lk in self.fieldMap:
                        for fm in self.fieldMap[lk].keys():
                            if fm.startswith(lk):
                                sql += ', string_agg(' + fm + '::varchar, \'|\') as "' + \
                                    self.fieldMap[lk][fm] + '"'
                        for rf in lig[3]:
                            if rf[0].startswith("lig_"):
                                sql += ', string_agg(distinct ' + rf[1] + \
                                    '.descricao, \'|\') as "' + rf[2] + '"'
                            else:
                                sql += ', string_agg(distinct ' + rf[0] + \
                                    '.descricao, \'|\') as "' + rf[1] + '"'
                    elif lig[1] is None and lig[0] in self.fieldMap:
                        for fm in self.fieldMap[lig[0]].keys():
                            sql += ', string_agg(distinct ' + fm + '::varchar, \'|\') as "' + \
                                self.fieldMap[lig[0]][fm] + '"'

            sql += ' from ' + layer

            for ref in self.flatLayers[layer]['refs']:
                sql += ' left join ' + \
                    ref + ' on ' + layer + '.'+ref+'=' + \
                    ref + '.identificador'

            for lig in self.flatLayers[layer]['ligs']:
                if lig[1] in self.layerList or lig[2] is True:
                    if lig[0] is not None:
                        sql += ' left join ' + \
                            lig[0] + ' on ' + layer + '.identificador=' + \
                            lig[0] + '.' + layer + '_id'
                        if lig[1] is not None:
                            sql += ' left join ' + \
                                lig[1] + ' on ' + lig[0] + '.' + lig[1] + \
                                '_id=' + lig[1] + '.identificador'
                    else:
                        sql += ' left join ' + \
                            lig[1][:-3] + ' on ' + layer + '.' + lig[1] + '=' + \
                            lig[1][:-3] + '.identificador'

                    for rf in lig[3]:
                        if rf[0].startswith("lig_"):
                            lk = lig[1] if not lig[1].endswith(
                                '_id') else lig[1][:-3]
                            sql += ' left join ' + \
                                rf[0] + ' on ' + lk + '.identificador=' + \
                                rf[0] + '.' + lk + '_id'
                            sql += ' left join ' + \
                                rf[1] + ' on ' + rf[0] + '.' + rf[1] + \
                                '_id=' + rf[1] + '.identificador'
                        else:
                            lk = lig[1] if lig[0] is not None else lig[1][:-3]
                            sql += ' left join ' + \
                                rf[0] + ' on ' + lk + '.'+rf[0]+'=' + \
                                rf[0] + '.identificador'

            sql += ' group by ' + layer + '.identificador'

        return sql

    def exportGeoJSON(self):
        driver = gdal.GetDriverByName('GeoJson')
        dest_srs = osr.SpatialReference()
        dest_srs.ImportFromEPSG(3763)

        for slayer in self.layerList:
            sql = self.getLayerSQL(slayer)

            try:
                datas = self.datasource.ExecuteSQL(sql)
            except Exception as e:
                self.write(
                    '[Erro]: Estrutura de dados inesperada ao exportar camada \'' + slayer + '\'')
                self.write(str(e))
                continue

            if not isinstance(datas, ogr.Layer):
                self.write(
                    '[Erro]: Estrutura de dados inesperada ao exportar camada \'' + slayer + '\'')
                continue

            outdata = driver.Create(
                self.outDir+'/'+slayer+'.geojson', 0, 0, 0, gdal.GDT_Unknown)
            outdata.CopyLayer(datas, slayer)

    def copy_layer_fields(self, datas, srslayer, outLayer):
        ofeat_defn = datas.GetLayerDefn()
        for ofi in range(ofeat_defn.GetFieldCount()):
            ofd = ofeat_defn.GetFieldDefn(ofi)
            name = ofd.GetNameRef()
            if name in self.fieldMap[srslayer]:
                name = self.fieldMap[srslayer][name]

            ofield_defn = ogr.FieldDefn(name, ofd.GetType())
            err = outLayer.CreateField(ofield_defn)
            # print('err' + str(err))

    def copy_feature_fields(self, datasrs, srsLayer, outLayer, feat):
        ofeat_defn = datasrs.GetLayerDefn()
        outFeature = ogr.Feature(outLayer.GetLayerDefn())
        outFeature.SetGeometry(feat.GetGeometryRef())
        for ofi in range(ofeat_defn.GetFieldCount()):
            ofd = ofeat_defn.GetFieldDefn(ofi)
            name = ofd.GetNameRef()
            if name in self.fieldMap[srsLayer]:
                name = self.fieldMap[srsLayer][name]
            outFeature.SetField(name, feat[ofd.GetNameRef()])
        outLayer.CreateFeature(outFeature)

    def exportShapefile(self):
        driver = gdal.GetDriverByName('ESRI Shapefile')

        oLayer = False
        for slayer in self.layerList:
            cLayer = False
            if slayer in self.flatLayers:
                dest_srs = osr.SpatialReference()
                dest_srs.ImportFromEPSG(3763)
                outLayers = {
                    'name': self.outDir+'/'+slayer,
                    'srs': dest_srs,
                    'pt_features': [],
                    'pl_features': [],
                    'ln_features': [],
                    'ng_features': []
                }

                sql = 'select ' + \
                    ', '.join(
                        [str(slayer + '.')+f for f in self.flatLayers[slayer]['fields']])

                for ref in self.flatLayers[slayer]['refs']:
                    sql += ', string_agg(distinct ' + ref + \
                        '.descricao, \'|\') as "' + ref + '"'

                for lig in self.flatLayers[slayer]['ligs']:
                    if lig[1] in self.layerList or lig[2] is True:
                        lk = lig[1] if lig[0] is not None else lig[1][:-3]
                        if lk in self.fieldMap:
                            for fm in self.fieldMap[lk].keys():
                                if fm.startswith(lk):
                                    sql += ', string_agg(' + fm + '::varchar, \'|\') as "' + \
                                        self.fieldMap[lk][fm] + '"'
                            for rf in lig[3]:
                                if rf[0].startswith("lig_"):
                                    sql += ', string_agg(distinct ' + rf[1] + \
                                        '.descricao, \'|\') as "' + rf[2] + '"'
                                else:
                                    sql += ', string_agg(distinct ' + rf[0] + \
                                        '.descricao, \'|\') as "' + rf[1] + '"'
                        elif lig[1] is None and lig[0] in self.fieldMap:
                            for fm in self.fieldMap[lig[0]].keys():
                                sql += ', string_agg(distinct ' + fm + '::varchar, \'|\') as "' + \
                                    self.fieldMap[lig[0]][fm] + '"'

                sql += ' from ' + slayer

                for ref in self.flatLayers[slayer]['refs']:
                    sql += ' left join ' + \
                        ref + ' on ' + slayer + '.'+ref+'=' + \
                        ref + '.identificador'

                for lig in self.flatLayers[slayer]['ligs']:
                    if lig[1] in self.layerList or lig[2] is True:
                        if lig[0] is not None:
                            sql += ' left join ' + \
                                lig[0] + ' on ' + slayer + '.identificador=' + \
                                lig[0] + '.' + slayer + '_id'
                            if lig[1] is not None:
                                sql += ' left join ' + \
                                    lig[1] + ' on ' + lig[0] + '.' + lig[1] + \
                                    '_id=' + lig[1] + '.identificador'
                        else:
                            sql += ' left join ' + \
                                lig[1][:-3] + ' on ' + slayer + '.' + lig[1] + '=' + \
                                lig[1][:-3] + '.identificador'

                        for rf in lig[3]:
                            if rf[0].startswith("lig_"):
                                lk = lig[1] if not lig[1].endswith(
                                    '_id') else lig[1][:-3]
                                sql += ' left join ' + \
                                    rf[0] + ' on ' + lk + '.identificador=' + \
                                    rf[0] + '.' + lk + '_id'
                                sql += ' left join ' + \
                                    rf[1] + ' on ' + rf[0] + '.' + rf[1] + \
                                    '_id=' + rf[1] + '.identificador'
                            else:
                                lk = lig[1] if lig[0] is not None else lig[1][:-3]
                                sql += ' left join ' + \
                                    rf[0] + ' on ' + lk + '.'+rf[0]+'=' + \
                                    rf[0] + '.identificador'

                sql += ' group by ' + slayer + '.identificador'
                # self.write(sql)

                try:
                    datas = self.datasource.ExecuteSQL(sql)
                except Exception as e:
                    self.write(
                        '[Erro]: Estrutura de dados inesperada ao exportar camada \'' + slayer + '\'')
                    self.write(str(e))
                    continue

                if not isinstance(datas, ogr.Layer):
                    self.write(
                        '[Erro]: Estrutura de dados inesperada ao exportar camada \'' + slayer + '\'')
                    continue

                feat = datas.GetNextFeature()
                while feat is not None:
                    # print(feat.ExportToJson())
                    if feat.GetGeometryRef() is None:
                        outLayers['ng_features'].append(feat)
                    elif feat.GetGeometryRef().GetGeometryType() == 1 or feat.GetGeometryRef().GetGeometryType() == -2147483647:  # POINT or Point25D
                        outLayers['pt_features'].append(feat)
                    elif feat.GetGeometryRef().GetGeometryType() == 3 or feat.GetGeometryRef().GetGeometryType() == 6 or feat.GetGeometryRef().GetGeometryType() == -2147483645:  # POLIGON or MULTIPOLYGON or Polygon25D
                        outLayers['pl_features'].append(feat)
                    elif feat.GetGeometryRef().GetGeometryType() == 2 or feat.GetGeometryRef().GetGeometryType() == -2147483646:  # LINE or LineString25D
                        outLayers['ln_features'].append(feat)
                    else:
                        print('unsupported geometry type:')
                        print(feat.GetGeometryRef().GetGeometryType())
                    feat = datas.GetNextFeature()
                feat = None

                if len(outLayers['pt_features']) > 0:
                    oLayer = True
                    cLayer = True
                    outdata = driver.Create(
                        self.outDir+'/'+slayer+'_point.shp', 0, 0, 0, gdal.GDT_Unknown)
                    outLayer = outdata.CreateLayer(
                        slayer+'_point', dest_srs, 1, options=['ENCODING='+self.outEncoding])
                    self.copy_layer_fields(datas, slayer, outLayer)
                    for feat in outLayers['pt_features']:
                        self.copy_feature_fields(datas, slayer, outLayer, feat)

                if len(outLayers['pl_features']) > 0:
                    oLayer = True
                    cLayer = True
                    outdata = driver.Create(
                        self.outDir+'/'+slayer+'_polygon.shp', 0, 0, 0, gdal.GDT_Unknown)
                    outLayer = outdata.CreateLayer(
                        slayer+'_polygon', dest_srs, 3, options=['ENCODING='+self.outEncoding])
                    self.copy_layer_fields(datas, slayer, outLayer)
                    for feat in outLayers['pl_features']:
                        self.copy_feature_fields(datas, slayer, outLayer, feat)

                if len(outLayers['ln_features']) > 0:
                    oLayer = True
                    cLayer = True
                    outdata = driver.Create(
                        self.outDir+'/'+slayer+'_line.shp', 0, 0, 0, gdal.GDT_Unknown)
                    outLayer = outdata.CreateLayer(
                        slayer+'_line', dest_srs, 2, options=['ENCODING='+self.outEncoding])
                    self.copy_layer_fields(datas, slayer, outLayer)
                    for feat in outLayers['ln_features']:
                        self.copy_feature_fields(datas, slayer, outLayer, feat)

                if len(outLayers['ng_features']) > 0:
                    oLayer = True
                    cLayer = True
                    outdata = driver.Create(
                        self.outDir+'/'+slayer+'_noGeom.shp', 0, 0, 0, gdal.GDT_Unknown)
                    outLayer = outdata.CreateLayer(
                        slayer+'_noGeom', dest_srs, 0, options=['ENCODING='+self.outEncoding])
                    self.copy_layer_fields(datas, slayer, outLayer)
                    for feat in outLayers['ng_features']:
                        self.copy_feature_fields(datas, slayer, outLayer, feat)

            if cLayer is not True:
                self.write(
                    '[Aviso] Não foram encontrados elementos para a camada \'' + slayer + '\'')
            else:
                self.write('[Sucesso] Camada \'' + slayer + '\' exportada')

        if self.exportAlias is True:
            with open(self.outDir+'/alias.json', "w") as alias_file:
                alias_file.write(json.dumps(
                    self.fieldMap, indent=4, ensure_ascii=False))

        if oLayer is not True:
            self.write('[Aviso] Não foram encontradas camadas válidas')
