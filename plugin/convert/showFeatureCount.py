def get_group_layers(group):
   # print('- group: ' + group.name())
   for child in group.children():
      if isinstance(child, QgsLayerTreeGroup):
         get_group_layers(child)
      else:
         child.setCustomProperty("showFeatureCount", True)
         print('  - layer: ' + child.name())

root = QgsProject.instance().layerTreeRoot()
for child in root.children():
   if isinstance(child, QgsLayerTreeGroup):
      get_group_layers(child)
   elif isinstance(child, QgsLayerTreeLayer):
      child.setCustomProperty("showFeatureCount", True)
      print ('- layer: ' + child.name())