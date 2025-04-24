#/***************************************************************************
# RecartDGT
#                                 A QGIS plugin
# Convert cartography datasets
#                             -------------------
#        begin                : 2020-07-02
#        copyright            : (C) 2020 by Geomaster
#        email                : geral@geomaster.pt
#        git sha              : $Format:%H$
# ***************************************************************************/
#
#/***************************************************************************
# *																		 *
# *   This program is free software; you can redistribute it and/or modify  *
# *   it under the terms of the GNU General Public License as published by  *
# *   the Free Software Foundation; either version 2 of the License, or	 *
# *   (at your option) any later version.								   *
# *																		 *
# ***************************************************************************/

#Add iso code for any locales you want to support here (space separated)
# default is no locales
LOCALES = pt

# If locales are enabled, set the name of the lrelease binary on your system. If
# you have trouble compiling the translations, you may have to specify the full path to
# lrelease
#LRELEASE = lrelease
#LRELEASE = lrelease-qt5

PLUGINNAME = recartDGT

PY_FILES = \
	__init__.py recartDGT.py\
	qgis_configs.py\
	postgis_helper.py\
	aux_export.py\
	main_dialog.py\
	convert_dialog.py\
	validation_dialog.py

UI_DIR = ui
UI_FILES = \
	$(UI_DIR)/main_dialog.ui \
	$(UI_DIR)/convert_dialog.ui \
	$(UI_DIR)/validation_dialog.ui

CONV_DIR = convert
CONV_FILES = \
	$(CONV_DIR)/conf.py $(CONV_DIR)/mapping_112.py\
	$(CONV_DIR)/mapping_201.py $(CONV_DIR)/mapping_202.py\
	$(CONV_DIR)/gm_cart_aux.py $(CONV_DIR)/gm_cart_postgis.py\
	$(CONV_DIR)/gm_cart_import.py

BASE_DIR_V112 = $(CONV_DIR)/base/v1.1.2
BASE_DIR_V201 = $(CONV_DIR)/base/v2.0.1
BASE_DIR_V202 = $(CONV_DIR)/base/v2.0.2

SCM_DIR = convert/schemas
SCM_FILES = \
	$(SCM_DIR)/base_schema.json $(SCM_DIR)/mapping_schema.json

PROC_DIR = convert/processing
PROC_FILES = \
	$(PROC_DIR)/polygonize.sql $(PROC_DIR)/to2D.py $(PROC_DIR)/to3D.py\
	$(PROC_DIR)/aux_views.sql

PROC_DIR_V112 = $(PROC_DIR)/v1.1.2
PROC_DIR_V201 = $(PROC_DIR)/v2.0.1
PROC_DIR_V202 = $(PROC_DIR)/v2.0.2

EXTRAS = metadata.txt icon.png carttop.xml validation_rules.sql validation_setup.sql validation_reset.sql validation_setup_no3d.sql

EXTRA_DIRS =

COMPILED_RESOURCE_FILES = resources5.py resources6.py

PEP8EXCLUDE=resources5.py,resources6.py,ui


#################################################
# Normally you would not need to edit below here
#################################################

HELP = help/build/html

PLUGIN_UPLOAD = $(c)/plugin_upload.py

RESOURCE_SRC=$(shell grep '^ *<file' resources.qrc | sed 's@</file>@@g;s/.*>//g' | tr '\n' ' ')

QGISDIR=.local/share/QGIS/QGIS3/profiles/default

default: compile

compile: $(COMPILED_RESOURCE_FILES)

%5.py : %.qrc $(RESOURCES_SRC)
	pyrcc5 -o $*5.py  $<

%6.py : %.qrc $(RESOURCES_SRC)
	pyside6-rcc -o $*6.py  $<

%.qm : %.ts
	$(LRELEASE) $<

test: compile transcompile
	@echo
	@echo "----------------------"
	@echo "Regression Test Suite"
	@echo "----------------------"

	@# Preceding dash means that make will continue in case of errors
	@-export PYTHONPATH=`pwd`:$(PYTHONPATH); \
		export QGIS_DEBUG=0; \
		export QGIS_LOG_FILE=/dev/null; \
		nosetests -v --with-id --with-coverage --cover-package=. \
		3>&1 1>&2 2>&3 3>&- || true
	@echo "----------------------"
	@echo "If you get a 'no module named qgis.core error, try sourcing"
	@echo "the helper script we have provided first then run make test."
	@echo "e.g. source run-env-linux.sh <path to qgis install>; make test"
	@echo "----------------------"

deploy: compile
	@echo
	@echo "------------------------------------------"
	@echo "Deploying plugin to your .qgis3 directory."
	@echo "------------------------------------------"
	# The deploy  target only works on unix like operating system where
	# the Python plugin directory is located at:
	# $HOME/$(QGISDIR)/python/plugins
	mkdir -p $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)
	mkdir -p $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(UI_DIR)
	mkdir -p $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(CONV_DIR)
	mkdir -p $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(BASE_DIR_V112)
	mkdir -p $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(BASE_DIR_V201)
	mkdir -p $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(BASE_DIR_V202)
	mkdir -p $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(SCM_DIR)
	mkdir -p $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(PROC_DIR)
	mkdir -p $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(PROC_DIR_V112)
	mkdir -p $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(PROC_DIR_V201)
	mkdir -p $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(PROC_DIR_V202)
	cp -vf $(PY_FILES) $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)
	cp -vf $(UI_FILES) $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(UI_DIR)/
	cp -vf $(CONV_FILES) $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(CONV_DIR)/
	cp -vrf $(BASE_DIR_V112)/* $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(BASE_DIR_V112)/
	cp -vrf $(BASE_DIR_V201)/* $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(BASE_DIR_V201)/
	cp -vrf $(BASE_DIR_V202)/* $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(BASE_DIR_V202)/
	cp -vf $(SCM_FILES) $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(SCM_DIR)/
	cp -vf $(PROC_FILES) $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(PROC_DIR)/
	cp -vrf $(PROC_DIR_V112)/* $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(PROC_DIR_V112)/
	cp -vrf $(PROC_DIR_V201)/* $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(PROC_DIR_V201)/
	cp -vrf $(PROC_DIR_V202)/* $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/$(PROC_DIR_V202)/
	cp -vf $(COMPILED_RESOURCE_FILES) $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)
	cp -vf $(EXTRAS) $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)
	# cp -vfr i18n $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)
	# cp -vfr $(HELP) $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/help
	# Copy extra directories if any
	# (foreach EXTRA_DIR,$(EXTRA_DIRS), cp -R $(EXTRA_DIR) $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)/;)


# The dclean target removes compiled python files from plugin directory
# also deletes any .git entry
dclean:
	@echo
	@echo "-----------------------------------"
	@echo "Removing any compiled python files."
	@echo "-----------------------------------"
	find $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME) -iname "*.pyc" -delete
	find $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME) -iname ".git" -prune -exec rm -Rf {} \;


derase:
	@echo
	@echo "-------------------------"
	@echo "Removing deployed plugin."
	@echo "-------------------------"
	rm -Rf $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)

zip: deploy dclean
	@echo
	@echo "---------------------------"
	@echo "Creating plugin zip bundle."
	@echo "---------------------------"
	# The zip target deploys the plugin and creates a zip file with the deployed
	# content. You can then upload the zip file on http://plugins.qgis.org
	rm -f $(PLUGINNAME).zip
	cd $(HOME)/$(QGISDIR)/python/plugins; zip -9r $(CURDIR)/$(PLUGINNAME).zip $(PLUGINNAME)

package: compile
	# Create a zip package of the plugin named $(PLUGINNAME).zip.
	# This requires use of git (your plugin development directory must be a
	# git repository).
	# To use, pass a valid commit or tag as follows:
	#   make package VERSION=Version_0.3.2
	@echo
	@echo "------------------------------------"
	@echo "Exporting plugin to zip package.	"
	@echo "------------------------------------"
	rm -f $(PLUGINNAME).zip
	git archive --prefix=$(PLUGINNAME)/ -o $(PLUGINNAME).zip $(VERSION)
	echo "Created package: $(PLUGINNAME).zip"

upload: zip
	@echo
	@echo "-------------------------------------"
	@echo "Uploading plugin to QGIS Plugin repo."
	@echo "-------------------------------------"
	$(PLUGIN_UPLOAD) $(PLUGINNAME).zip

transup:
	@echo
	@echo "------------------------------------------------"
	@echo "Updating translation files with any new strings."
	@echo "------------------------------------------------"
	@chmod +x scripts/update-strings.sh
	@scripts/update-strings.sh $(LOCALES)

transcompile:
	@echo
	@echo "----------------------------------------"
	@echo "Compiled translation files to .qm files."
	@echo "----------------------------------------"
	@chmod +x scripts/compile-strings.sh
	@scripts/compile-strings.sh $(LRELEASE) $(LOCALES)

transclean:
	@echo
	@echo "------------------------------------"
	@echo "Removing compiled translation files."
	@echo "------------------------------------"
	rm -f i18n/*.qm

clean:
	@echo
	@echo "------------------------------------"
	@echo "Removing uic and rcc generated files"
	@echo "------------------------------------"
	rm $(COMPILED_UI_FILES) $(COMPILED_RESOURCE_FILES)

doc:
	@echo
	@echo "------------------------------------"
	@echo "Building documentation using sphinx."
	@echo "------------------------------------"
	cd help; make html

pylint:
	@echo
	@echo "-----------------"
	@echo "Pylint violations"
	@echo "-----------------"
	@pylint --reports=n --rcfile=pylintrc . || true
	@echo
	@echo "----------------------"
	@echo "If you get a 'no module named qgis.core' error, try sourcing"
	@echo "the helper script we have provided first then run make pylint."
	@echo "e.g. source run-env-linux.sh <path to qgis install>; make pylint"
	@echo "----------------------"


# Run pep8 style checking
#http://pypi.python.org/pypi/pep8
pep8:
	@echo
	@echo "-----------"
	@echo "PEP8 issues"
	@echo "-----------"
	@pep8 --repeat --ignore=E203,E121,E122,E123,E124,E125,E126,E127,E128 --exclude $(PEP8EXCLUDE) . || true
	@echo "-----------"
	@echo "Ignored in PEP8 check:"
	@echo $(PEP8EXCLUDE)
