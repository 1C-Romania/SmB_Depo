////////////////////////////////////////////////////////////////////////////////
// Standard functionality

&AtClient
Procedure GroupFieldsUnavailable()
	
	Items.GroupFieldsPages.CurrentPage = Items.GroupFieldsSettingsInaccessible;
					
EndProcedure

&AtClient
Procedure SelectedFieldsAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemSelection(StructureItem) Then
				
		LocalSelectedFields = True;
		Items.SelectedFieldsPages.CurrentPage = Items.SelectedFieldsSettings;
			
	Else
			
		LocalSelectedFields = False;
		Items.SelectedFieldsPages.CurrentPage = Items.SelectedFieldsSettingsOff;
			
	EndIf;
		
	Items.LocalSelectedFields.ReadOnly = False;
					
EndProcedure

&AtClient
Procedure SelectedFieldsUnavailable()
	
	LocalSelectedFields = False;
	Items.LocalSelectedFields.ReadOnly = True;
	Items.SelectedFieldsPages.CurrentPage = Items.SelectedFieldsSettingsInaccessible;
					
EndProcedure

&AtClient
Procedure FilterAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemFilter(StructureItem) Then
		
		LocalFilter = True;
		Items.FilterPages.CurrentPage = Items.SettingsOFFilter;
			
	Else
		
		LocalFilter = False;
		Items.FilterPages.CurrentPage = Items.FilterSettingsOff;
			
	EndIf;
			
	Items.LocalFilter.ReadOnly = False;
	
EndProcedure
		
&AtClient
Procedure FilterUnavailable()
	
	LocalFilter = False;
	Items.LocalFilter.ReadOnly = True;
	Items.FilterPages.CurrentPage = Items.FilterSettingsInaccessible;
		
EndProcedure

&AtClient
Procedure OrderAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemOrder(StructureItem) Then
		
		LocalOrder = True;
		Items.OrderPages.CurrentPage = Items.OrderSettings;
					
	Else
		
		LocalOrder = False;
		Items.OrderPages.CurrentPage = Items.OrderSettingsOff;
					
	EndIf;
			
	Items.LocalOrder.ReadOnly = False;
		
EndProcedure

&AtClient
Procedure OrderUnavailable()
	
	LocalOrder = False;
	Items.LocalOrder.ReadOnly = True;
	Items.OrderPages.CurrentPage = Items.OrderSettingsInaccessible;
		
EndProcedure

&AtClient
Procedure ConditionalAppearanceAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemConditionalAppearance(StructureItem) Then
		
		LocalConditionalAppearance = True;
		Items.ConditionalAppearancePages.CurrentPage = Items.ConditionalAppearanceSettings;
					
	Else
		
		LocalConditionalAppearance = False;
		Items.ConditionalAppearancePages.CurrentPage = Items.ConditionalAppearanceSettingsOff;
					
	EndIf;
			
	Items.LocalConditionalAppearance.ReadOnly = False;
		
EndProcedure

&AtClient
Procedure ConditionalAppearanceUnavailable()
	
	LocalConditionalAppearance = False;
	Items.LocalConditionalAppearance.ReadOnly = True;
	Items.ConditionalAppearancePages.CurrentPage = Items.ConditionalAppearanceSettingsInaccessible;
		
EndProcedure

&AtClient
Procedure OutputParametersAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemOutputParameters(StructureItem) Then
		
		LocalOutputParameters = True;
		Items.OutputParametersPages.CurrentPage = Items.OutputParametersSettings;
					
	Else
		
		LocalOutputParameters = False;
		Items.OutputParametersPages.CurrentPage = Items.OutputParametersSettingsOff;
					
	EndIf;
			
	Items.LocalOutputParameters.ReadOnly = False;
		
EndProcedure

&AtClient
Procedure OutputParametersUnavailable()
	
	LocalOutputParameters = False;
	Items.LocalOutputParameters.ReadOnly = True;
	Items.OutputParametersPages.CurrentPage = Items.OutputParametersSettingsInaccessible;
	
EndProcedure

&AtClient
Procedure SettingsComposerSettingOnActivateField(Item)
		
	Var SelectedPage;
	
	If Items.SettingsComposerSettings.CurrentItem.Name = "SettingsComposerSettingChoiceExistence" Then
		
		SelectedPage = Items.SelectedFieldsPage;
		
	ElsIf Items.SettingsComposerSettings.CurrentItem.Name = "SettingsComposerSettingFilterExistence" Then
		
		SelectedPage = Items.FilterPage;
		
	ElsIf Items.SettingsComposerSettings.CurrentItem.Name = "SettingsComposerSettingOrderExistence" Then
		
		SelectedPage = Items.OrderPage;
		
	ElsIf Items.SettingsComposerSettings.CurrentItem.Name = "SettingsComposerSettingConditionalAppearanceExistence" Then
		
		SelectedPage = Items.ConditionalAppearancePage;
		
	ElsIf Items.SettingsComposerSettings.CurrentItem.Name = "SettingsComposerSettingOutputParametersExistence" Then
		
		SelectedPage = Items.OutputParametersPage;
		
	EndIf;
	
	If SelectedPage <> Undefined Then
		
		Items.SettingPages.CurrentPage = SelectedPage;
		
	EndIf;

EndProcedure

&AtClient
Procedure SettingsComposerSettingOnActivateRow(Item)
	
	StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingsComposerSettings.CurrentRow);
	PointType = TypeOf(StructureItem); 
	
	If PointType = Undefined  OR
		 PointType = Type("DataCompositionChartStructureItemCollection") OR
		 PointType = Type("DataCompositionTableStructureItemCollection") Then
		 
		GroupFieldsUnavailable();
		SelectedFieldsUnavailable();
		FilterUnavailable();
		OrderUnavailable();
		ConditionalAppearanceUnavailable();
		OutputParametersUnavailable();
		
	ElsIf PointType = Type("DataCompositionSettings") OR
		 	  PointType = Type("DataCompositionNestedObjectSettings") Then
		
		GroupFieldsUnavailable();
		
		LocalSelectedFields = True;
		Items.LocalSelectedFields.ReadOnly = True;
		Items.SelectedFieldsPages.CurrentPage = Items.SelectedFieldsSettings;
		
		LocalFilter = True;
		Items.LocalFilter.ReadOnly = True;
		Items.FilterPages.CurrentPage = Items.SettingsOFFilter;
		
		LocalOrder = True;
		Items.LocalOrder.ReadOnly = True;
		Items.OrderPages.CurrentPage = Items.OrderSettings;
		
		LocalConditionalAppearance = True;
		Items.LocalConditionalAppearance.ReadOnly = True;
		Items.ConditionalAppearancePages.CurrentPage = Items.ConditionalAppearanceSettings;
		
		LocalOutputParameters = True;
		Items.LocalOutputParameters.ReadOnly = True;
		Items.OutputParametersPages.CurrentPage = Items.OutputParametersSettings;
		
	ElsIf PointType = Type("DataCompositionGroup") OR
		 	  PointType = Type("DataCompositionTableGroup") OR
		 	  PointType = Type("DataCompositionChartGroup") Then
		 
		Items.GroupFieldsPages.CurrentPage = Items.GroupFieldsSettings;
			
		SelectedFieldsAvailable(StructureItem);
		FilterAvailable(StructureItem);
		OrderAvailable(StructureItem);
		ConditionalAppearanceAvailable(StructureItem);
		OutputParametersAvailable(StructureItem);
		
	ElsIf PointType = Type("DataCompositionTable") OR
		      PointType = Type("DataCompositionChart") Then
		
		GroupFieldsUnavailable();
		SelectedFieldsAvailable(StructureItem);
		FilterUnavailable();
		OrderUnavailable();
		ConditionalAppearanceAvailable(StructureItem);
		OutputParametersAvailable(StructureItem);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToReport(Item)
	
	StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingsComposerSettings.CurrentRow);
	ItemSettings =  Report.SettingsComposer.Settings.ItemSettings(StructureItem);
	Items.SettingsComposerSettings.CurrentRow = Report.SettingsComposer.Settings.GetIDByObject(ItemSettings);
	
EndProcedure

&AtClient
Procedure LocalSelectedFieldsOnChange(Item)
	
	If LocalSelectedFields Then
		
		Items.SelectedFieldsPages.CurrentPage = Items.SelectedFieldsSettings;
			
	Else
		
		Items.SelectedFieldsPages.CurrentPage = Items.SelectedFieldsSettingsOff;

		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingsComposerSettings.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemSelection(StructureItem);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure LocalFilterOnChange(Item)
	
	If LocalFilter Then
		
		Items.FilterPages.CurrentPage = Items.SettingsOFFilter;
			
	Else
		
		Items.FilterPages.CurrentPage = Items.FilterSettingsOff;

		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingsComposerSettings.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemFilter(StructureItem);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure LocalOrderOnChange(Item)
	
	If LocalOrder Then
		
		Items.OrderPages.CurrentPage = Items.OrderSettings;
					
	Else
		
		Items.OrderPages.CurrentPage = Items.OrderSettingsOff;
					
		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingsComposerSettings.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemOrder(StructureItem);
		
	EndIf;
				
EndProcedure

&AtClient
Procedure LocalConditionalAppearanceOnChange(Item)

	If LocalConditionalAppearance Then
		
		Items.ConditionalAppearancePages.CurrentPage = Items.ConditionalAppearanceSettings;
					
	Else
		
		Items.ConditionalAppearancePages.CurrentPage = Items.ConditionalAppearanceSettingsOff;
					
		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingsComposerSettings.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemConditionalAppearance(StructureItem);
					
	EndIf;
				
EndProcedure

&AtClient
Procedure LocalOutputParametersOnChange(Item)
	
	If LocalOutputParameters Then
		
		Items.OutputParametersPages.CurrentPage = Items.OutputParametersSettings;
					
	Else
		
		Items.OutputParametersPages.CurrentPage = Items.OutputParametersSettingsOff;
					
		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingsComposerSettings.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemOutputParameters(StructureItem);
	EndIf;
			
EndProcedure

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("VariantPresentation") AND ValueIsFilled(Parameters.VariantPresentation) Then
		AutoTitle = False;
		Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Change report variant ""%1""';ru='Изменение варианта отчета ""%1""'"),
			Parameters.VariantPresentation);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure FinishEdit(Command)
	If ModalMode
		Or WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface
		Or FormOwner = Undefined Then
		Close(True);
	Else
		ChoiceResult = New Structure;
		ChoiceResult.Insert("VariantModified", False);
		ChoiceResult.Insert("UserSettingsModified", False);
		
		If VariantModified Then
			ChoiceResult.VariantModified = True;
			ChoiceResult.Insert("DCSettings", Report.SettingsComposer.Settings);
		EndIf;
		
		If VariantModified Or UserSettingsModified Then
			ChoiceResult.UserSettingsModified = True;
			ChoiceResult.Insert("DCUserSettings", Report.SettingsComposer.UserSettings);
		EndIf;
		
		NotifyChoice(ChoiceResult);
	EndIf;
EndProcedure

#EndRegion
