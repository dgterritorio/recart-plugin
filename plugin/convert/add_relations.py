project = QgsProject.instance()
manager = project.relationManager()
relations = manager.relations()
layers = QgsProject.instance().mapLayers()

rels = manager.discoverRelations( relations.values(), layers.values() )

print( "Relações encontradas: ".format( len(rels) ) )

for rel in rels:
    # if rel.name().startswith('valor_zona'):
    manager.addRelation(rel)
    print(rel.name(), rel.referencedLayer().name(), rel.referencingLayer().name())
    layer = rel.referencingLayer()
    fields = layer.fields()
    field = fields[ rel.referencingFields()[0] ]
    field_idx = fields.indexOf(field.name())
    config = {
        'Relation': rel.id()
    }
    widget_setup = QgsEditorWidgetSetup('RelationReference',config)
    layer.setEditorWidgetSetup(field_idx, widget_setup)
    print( "Camada {} configurada com base na relação".format( layer.name() ) )

from qgis.PyQt.QtTest import QSignalSpy
layer_was_added_spy = QSignalSpy(QgsProject.instance().layerWasAdded)
layers_added_spy = QSignalSpy(QgsProject.instance().layersAdded)
len(layer_was_added_spy)
len(layers_added_spy)



        
