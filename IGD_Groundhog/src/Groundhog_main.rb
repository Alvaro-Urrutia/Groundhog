module IGD
	module Groundhog
		# MAIN
		# Groundhog.RB

		#Check SU version.
		version_required = 15
		actual_version = Sketchup.version_number

		if (actual_version < version_required)
		  UI.messagebox("Groundhog is being developed and tested using Sketchup 20" + version_required.to_i.to_s +
						". Since it seems that you are using an older version, some features might not work correctly."+
						"\n\n You can upgrade SketchUp going to "+
						"www.SketchUp.com")
		end

		#################################

		Sketchup::require 'IGD_Groundhog/src/Triangle'
		Sketchup::require 'IGD_Groundhog/src/Utilities'
		Sketchup::require 'IGD_Groundhog/src/Config'
		Sketchup::require 'IGD_Groundhog/src/Labeler'
		Sketchup::require 'IGD_Groundhog/src/OS'
		Sketchup::require 'IGD_Groundhog/src/Exporter'
		Sketchup::require 'IGD_Groundhog/src/Results'
		Sketchup::require 'IGD_Groundhog/src/Materials'
		Sketchup::require 'IGD_Groundhog/src/Rad'
		Sketchup::require 'IGD_Groundhog/src/LoadHandler'
		Sketchup::require 'IGD_Groundhog/src/Addons'
		Sketchup::require 'IGD_Groundhog/src/Color'
		Sketchup::require 'IGD_Groundhog/src/Luminaires'



		require 'json'
		require 'Open3'
		require 'fileutils'
		#require 'open-uri'



		#########################################
		model=Sketchup.active_model
		selection=model.selection
		entities=model.entities



		#######################
		### CONTEXT MENUS
		#######################

		UI.add_context_menu_handler do |context_menu|
			context_menu.add_separator
		end

		UI.add_context_menu_handler do |context_menu|
		   faces=Utilities.get_faces(Sketchup.active_model.selection)
		   namables = Utilities.get_namables(Sketchup.active_model.selection)
		   components = Utilities.get_components(Sketchup.active_model.selection)
			 groups = Utilities.get_groups(Sketchup.active_model.selection)

		   if namables.length >= 1 then
			   context_menu.add_item("Assign Name") {
					begin
						op_name = "Assign name"
						model.start_operation(op_name,true)
						name=Utilities.get_name
						model.abort_operation if not name
						Labeler.set_name(Sketchup.active_model.selection,name)
						model.commit_operation
					rescue => e
						model.abort_operation
						OS.failed_operation_message(op_name)
					end
			   }
	   		end

			if components.length == 1 then
				context_menu.add_item("Label as Luminaire") {
					begin
						op_name = "Link IES file"
						model.start_operation(op_name,true)
						comp = components[0].definition

						Labeler.to_local_luminaire(comp)
						model.commit_operation
					rescue => e
						model.abort_operation
						OS.failed_operation_message(op_name)
					end
			   }
			end

			if groups.length == 1 then
				group=groups[0]
				if Labeler.solved_workplane?(group) then
					context_menu.add_item("Export results to CSV") {
						begin
							op_name = "Export workplane to CSV"
							model.start_operation(op_name,true)

							path=Exporter.getpath #it returns false if not successful
							path="" if not path
							filename="#{Labeler.get_name(group)}.csv"
							filename=UI.savepanel("Export CSV file of results",path,filename)

							if filename then
								File.open(filename,'w'){|csv|
									statistics = Results.get_workplane_statistics(group)
									#write statistics
									statistics.to_a.each{|element|
										csv.puts "#{element[0]},#{element[1]}"
									}
									#Write header
									csv.puts "Position X, Position Y, Position Z, Value (depends on the metric)"
									#Write pixels
									pixels = group.entities.select{|x| Labeler.result_pixel?(x)}
									pixels.each do |pixel|
										vertices=pixel.vertices
										nvertices=vertices.length
										center=vertices.shift.position.to_a
										vertices.each{|vert|
											pos=vert.position.to_a
											center[0]+=pos[0]
											center[1]+=pos[1]
											center[2]+=pos[2]
										}
										csv.puts "#{(center[0]/nvertices).to_m},#{(center[1]/nvertices).to_m},#{(center[2]/nvertices).to_m},#{Labeler.get_value(pixel)}"
									end
								}
							end

							model.commit_operation
						rescue => e
							model.abort_operation
							OS.failed_operation_message(op_name)
						end
				   }
				end
			end

			if faces.length>=1 then
				context_menu.add_item("Label as Illum") {
					begin
						op_name = "Label as Illum"
						model.start_operation( op_name ,true)

						Labeler.to_illum(faces)

						model.commit_operation
					rescue => e
						model.abort_operation
						OS.failed_operation_message(op_name)
					end
			   }
				horizontal=Utilities.get_horizontal_faces(faces)
				if horizontal.length >=1 then
				   context_menu.add_item("Label as Workplane") {
							begin
								op_name = "Label as Workplane"
								model.start_operation( op_name,true )

								Labeler.to_workplane(faces)

								model.commit_operation
							rescue => e
								model.abort_operation
								OS.failed_operation_message(op_name)
							end
				   }
				end
			   context_menu.add_item("Label as Window") {
					begin
						op_name = "Label as Window"
						model.start_operation( op_name ,true)

						Labeler.to_window(faces)

						model.commit_operation
					rescue => e
						model.abort_operation
						OS.failed_operation_message(op_name)
					end
			   }

				context_menu.add_item("Remove Labels") {
					begin
						op_name = "Remove Labels"
						model.start_operation( op_name, true)

						Labeler.to_nothing(faces)

						model.commit_operation
					rescue => e
						model.abort_operation
						OS.failed_operation_message(op_name)
					end
			   }
			   wins=Utilities.get_windows(faces)
				if wins.length>1 then
				   context_menu.add_item("Group windows") {
						begin
							op_name = "Group windows"
							model.start_operation(op_name,true)

							prompts=["Name of the window group"]
							defaults=[]
							sys=UI.inputbox prompts, defaults, "Name of the window group"
							model.abort_operation if not sys
							Utilities.group_windows(Sketchup.active_model.selection, sys[0])

							model.commit_operation
						rescue => e
							model.abort_operation
							OS.failed_operation_message(op_name)
						end
				   }
				end

			end
		end









		#######################
		### MENUS
		#######################

		### GROUNDHOG MENU

		extensions_menu = UI.menu "Plugins"
		groundhog_menu=extensions_menu.add_submenu("Groundhog")


			### EXPORT
			groundhog_menu.add_item("Export to Radiance") {

				path=Exporter.getpath #it returns false if not successful
				path="" if not path

				path_to_save = UI.savepanel("Export model for radiance simulations", path, "Radiance Model")

				if path_to_save then
					OS.mkdir(path_to_save)
					Exporter.export(path_to_save,true) #lights on
				end
			}


			groundhog_menu.add_item("Simulation Wizard"){
				Rad.show_sim_wizard
			}


			### INSERT SUBMENU

			gh_insert_menu=groundhog_menu.add_submenu("Insert")

				gh_insert_menu.add_item("Materials"){
					Materials.show_material_wizard
				}

				gh_insert_menu.add_item("Illuminance Sensor"){
					Loader.load_illuminance_sensor
				}

				gh_insert_menu.add_item("Products from Arqhub"){
					Loader.open_arqhub
				}

			### RESULTS SUBMENU

			gh_results_menu=groundhog_menu.add_submenu("Results")

				gh_results_menu.add_item("Import results"){

					path=Exporter.getpath #it returns false if not successful
					path="c:/" if not path
					path=UI.openpanel("Open results file",path)
					Results.import_results(path,false) if path


				}

				gh_results_menu.add_item("Scale handler"){
					Results.show_scale_handler

				}




			### VIEW
			gh_view_menu=groundhog_menu.add_submenu("View")

				gh_view_menu.add_item("Show/Hide illums"){
					Utilities.hide_show_specific("illum")
				}
				gh_view_menu.add_item("Show/Hide Workplanes"){
					Utilities.hide_show_specific("workplane")
				}
				gh_view_menu.add_item("Show/Hide Results"){
					Utilities.hide_show_specific("solved_workplane")
				}




			### PREFERENCES MENU
			groundhog_menu.add_item("Preferences") {
				Config.show_config
			}

			### ADD-ONS MENU
			@gh_addons_menu=groundhog_menu.add_submenu("Add-ons")
				@gh_addons_menu.add_item("Add-on manager") {
					Addons.show_addons_manager
				}

			def self.addon_menu
				return @gh_addons_menu
			end

			### EXAMPLES MENU
			gh_examples_menu=groundhog_menu.add_submenu("Example files")
				gh_examples_menu.add_item("University Hall") {
					path = "#{OS.examples_groundhog_path}/UniversityHall.skp"
					UI.messagebox("Unable to open Example File.") if not Sketchup.open_file path
				}

			### HELP MENU

			gh_help_menu=groundhog_menu.add_submenu("Help")
				gh_help_menu.add_item("Full Groundhog documentation") {
					wd=UI::WebDialog.new(
						"Full doc", true, "",
						700, 700, 100, 100, true )
					wd.set_file("#{OS.main_groundhog_path}/doc/doc_index.html" )
					wd.show()
				}

				## Tutorials
				gh_tutorials_menu=gh_help_menu.add_submenu("Tutorials")
					gh_tutorials_menu.add_item("Getting Started") {
						wd=UI::WebDialog.new(
							"Tutorials", true, "",
							700, 700, 100, 100, true )
						wd.set_file( "#{OS.main_groundhog_path}/doc/file.GettingStarted.html" )
						wd.show()
					}
					gh_tutorials_menu.add_item("Adding windows") {
						wd=UI::WebDialog.new(
							"Tutorials", true, "",
							700, 700, 100, 100, true )
						wd.set_file("#{OS.main_groundhog_path}/doc/file.MakeWindow.html" )
						wd.show()
					}
					gh_tutorials_menu.add_item("Adding workplanes") {
						wd=UI::WebDialog.new(
							"Tutorials", true, "",
							700, 700, 100, 100, true )
						wd.set_file("#{OS.main_groundhog_path}/doc/file.MakeWorkplane.html" )
						wd.show()
					}
					gh_tutorials_menu.add_item("Adding illums") {
						wd=UI::WebDialog.new(
							"Tutorials", true, "",
							700, 700, 100, 100, true )
						wd.set_file("#{OS.main_groundhog_path}/doc/file.MakeIllum.html" )
						wd.show()
					}
					gh_tutorials_menu.add_item("Exporting views") {
						wd=UI::WebDialog.new(
							"Tutorials", true, "",
							700, 700, 100, 100, true )
						wd.set_file("#{OS.main_groundhog_path}/doc/file.Views.html" )
						wd.show()
					}
					gh_tutorials_menu.add_item("Visualizing results") {
						wd=UI::WebDialog.new(
							"Tutorials", true, "",
							700, 700, 100, 100, true )
						wd.set_file("#{OS.main_groundhog_path}/doc/file.ImportResults.html" )
						wd.show()
					}

			# Add the About.
			groundhog_menu.add_item("About Groundhog"){
				str="Groundhog version "+Sketchup.extensions["Groundhog"].version.to_s+"\n\nGroundhog was created and it is mainly developed by "+Sketchup.extensions["Groundhog"].creator+", currently working at IGD.\n\nCopyright:\n"+Sketchup.extensions["Groundhog"].copyright
				str+="\n\nLicense:\nGroundhog is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

Go to GNU's website for more information about this license."
				UI.messagebox str
			}




			#########################################
			# LOAD CONFIG FILE
			#########################################
			if File.exists? Config.config_path then #if a configuration file was once created
				Config.load_config
			end


	end #end module
end