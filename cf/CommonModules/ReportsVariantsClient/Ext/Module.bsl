////////////////////////////////////////////////////////////////////////////////
// "Reports variants" subsystem (client).
// 
// Executed on client.
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Opens the reports panel. Used in module of common command.
//
// Parameters:
//   PathToSubsystem - String - Section name or path to the subsystem for which the report panel is opened.
//       It is set in format: "SectionName[.NestedSubsystem1Name][.NestedSubsystems2Name][...]".
//       NB! Section must be described in ReportsVariantsOverridable.DetermineSectionsWithReportsVariants.
//   CommandExecuteParameters - CommandExecuteParameters - It is passed "as is" from the handler command parameters.
//
Procedure ShowReportsPanel(PathToSubsystem, CommandExecuteParameters, Delete_Title = "") Export
	ParametersForm = New Structure("PathToSubsystem", PathToSubsystem);
	WindowForm = ?(CommandExecuteParameters = Undefined, Undefined, CommandExecuteParameters.Window);
	OpenForm("CommonForm.ReportsPanel", ParametersForm, , PathToSubsystem, WindowForm);
EndProcedure

// Opens the location setup dialog of several variants in sections.
//   It is recommended to perform checks before the call.
//
// Parameters:
//   OptionsArray - Array from CatalogRef.ReportsVariants - Report variants for which the dialog is opened.
//   AdditionalParameters (*) Optional.
//   Owner - ManagedForm - Optional. Used only to block the owner window.
//
Procedure OpenPlacingVariantsInSectionsDialog(OptionsArray, AdditionalParameters = Undefined, Owner = Undefined) Export
	
	If TypeOf(OptionsArray) <> Type("Array") OR OptionsArray.Count() < 1 Then
		ShowMessageBox(, NStr("en='Select report variants to be placed in sections.';ru='Выберите варианты отчетов, которые необходимо разместить в разделах.'"));
		Return;
	EndIf;
	
	OpenParameters = New Structure("OptionsArray, AdditionalParameters", OptionsArray, AdditionalParameters);
	OpenForm("Catalog.ReportsVariants.Form.PlacementInSections", OpenParameters, Owner);
	
EndProcedure

// Opens the user settings reset dialog of selected report variants.
//   It is recommended to perform checks before the call.
//
// Parameters:
//   OptionsArray - Array from CatalogRef.ReportsVariants - Report variants for which the dialog is opened.
//   Owner - ManagedForm - Optional. Used only to block the owner window.
//
Procedure OpenUsersSettingsResetDialog(OptionsArray, Owner = Undefined) Export
	
	If TypeOf(OptionsArray) <> Type("Array") OR OptionsArray.Count() < 1 Then
		ShowMessageBox(, NStr("en='Select report variants for which it is required to reset the custom settings.';ru='Выберите варианты отчетов, для которых необходимо сбросить пользовательские настройки.'"));
		Return;
	EndIf;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("OptionsArray", OptionsArray);
	OpenForm("Catalog.ReportsVariants.Form.ResetUserSettings", OpenParameters, Owner);
	
EndProcedure

// Opens the location settings reset dialog of selected application report variants.
//   It is recommended to perform checks before the call.
//
// Parameters:
//   OptionsArray - Array from CatalogRef.ReportsVariants - Report variants for which the dialog is opened.
//   Owner - ManagedForm - Optional. Used only to block the owner window.
//
Procedure OpenDirectoryPropertiesResetDialog(OptionsArray, Owner = Undefined) Export
	
	If TypeOf(OptionsArray) <> Type("Array") OR OptionsArray.Count() < 1 Then
		ShowMessageBox(, NStr("en='Select the application report variants which location settings are to be reset.';ru='Выберите варианты отчетов программы, для которых необходимо сбросить настройки размещения.'"));
		Return;
	EndIf;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("OptionsArray", OptionsArray);
	OpenForm("Catalog.ReportsVariants.Form.ResetLocationSettings", OpenParameters, Owner);
	
EndProcedure

// Notifies the public report panels, lists and items forms about changes.
//
// Parameters:
//   Parameter - Arbitrary - Optional. Any necessary data can be transferred.
//   Source - Arbitrary - Optional. The event source. For example you can pass another form.
//
Procedure OpenFormsRefresh(Parameter = Undefined, Source = Undefined) Export
	
	Notify(ReportsVariantsClientServer.EventNameOptionChanging(), Parameter, Source);
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// Opens a report form.
//
// Parameters:
//   ReportParameters - Structure - Main information about the report necessary for its opening.
//   FormParameters - Structure - Opening parameters of the report form.
//
Procedure Open(ReportParameters, FormParameters, Owner) Export
	
	Uniqueness = ReportParameters.FullName;
	If ValueIsFilled(ReportParameters.VariantKey) Then
		Uniqueness = Uniqueness + "/VariantKey." + ReportParameters.VariantKey;
	EndIf;
	
	If FormParameters = Undefined Then
		FormParameters = New Structure;
	EndIf;
	
	FormParameters.Insert("VariantKey", ReportParameters.VariantKey);
	FormParameters.Insert("PrintParametersKey", Uniqueness);
	FormParameters.Insert("WindowOptionsKey", Uniqueness);
	
	OpenForm(ReportParameters.FullName + ".Form", FormParameters, Owner, Uniqueness);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Opens a report form.
//
// Parameters:
//   Form - ManagedForm - Form where the report is opened from.
//
Procedure OpenReportOption(Form) Export
	If Form.FormName = "Catalog.ReportsVariants.Form.ListForm" Then
		Variant = Form.Items.List.CurrentData;
	ElsIf Form.FormName = "Catalog.ReportsVariants.Form.ItemForm" Then
		Variant = Form.Object;
	Else
		Return;
	EndIf;
	
	If Variant = Undefined OR Variant.Ref.IsEmpty() Then
		
		ShowMessageBox(, NStr("en='Select report variant.';ru='Выберите вариант отчета.'"));
		
	ElsIf Variant.ReportType = PredefinedValue("Enum.ReportsTypes.External") Then
		
		ShowMessageBox(, NStr("en='External report variant can be opened only from the report form.';ru='Вариант внешнего отчета можно открыть только из формы отчета.'"));
		
	ElsIf Variant.ReportType = PredefinedValue("Enum.ReportsTypes.Additional") Then
		
		OpenParameters = New Structure("Ref, Report, KeyVariant");
		FillPropertyValues(OpenParameters, Variant);
		OpenAdditionalReportVariants(OpenParameters);
		
	Else
		
		If Form.FormName = "Catalog.ReportsVariants.Form.ListForm" Then
			ReportName = Variant.ReportName;
		Else
			ReportName = Form.ReportName;
		EndIf;
		
		Uniqueness = "Report." + ReportName;
		If ValueIsFilled(Variant.VariantKey) Then
			Uniqueness = Uniqueness + "/VariantKey." + Variant.VariantKey;
		EndIf;
		
		OpenParameters = New Structure;
		OpenParameters.Insert("VariantKey", Variant.VariantKey);
		OpenParameters.Insert("PrintParametersKey", Uniqueness);
		OpenParameters.Insert("WindowOptionsKey", Uniqueness);
		
		OpenForm("Report." + ReportName + ".Form", OpenParameters, Undefined, Uniqueness);
		
	EndIf;
EndProcedure

// Opens the settings form (in particular location) of the report variant.
Procedure ShowReportSettings(VariantRef) Export
	FormParameters = New Structure;
	FormParameters.Insert("LocationSetup", True);
	FormParameters.Insert("Key", VariantRef);
	OpenForm("Catalog.ReportsVariants.ObjectForm", FormParameters);
EndProcedure

// Procedure serves the event of SubsystemsTree attribute in editing forms.
Procedure SubsystemsTreeUsingOnChange(Form, Item) Export
	TreeRow = Form.Items.SubsystemsTree.CurrentData;
	If TreeRow = Undefined Then
		Return;
	EndIf;
	
	// Root line pass
	If TreeRow.Priority = "" Then
		TreeRow.Use = 0;
		Return;
	EndIf;
	
	If TreeRow.Use = 2 Then
		TreeRow.Use = 0;
	EndIf;
	
	TreeRow.Modified = True;
EndProcedure

// Procedure serves the event of SubsystemsTree attribute in editing forms.
Procedure SubsystemsTreeImportanceOnChange(Form, Item) Export
	TreeRow = Form.Items.SubsystemsTree.CurrentData;
	If TreeRow = Undefined Then
		Return;
	EndIf;
	
	// Root line pass
	If TreeRow.Priority = "" Then
		TreeRow.Importance = "";
		Return;
	EndIf;
	
	If TreeRow.Importance <> "" Then
		TreeRow.Use = 1;
	EndIf;
	
	TreeRow.Modified = True;
EndProcedure

// Analog CommonUseClient.ShowMultiLineTexrEditingFrom running for 1 call.
//   Unlike CommonUseClient.ShowCommentEditingForm allows to set own
//   title and works with attributes of tables.
//
Procedure EditMultilineText(FormOrHandler, EditText, PropsOwner, AttributeName, Val Title = "") Export
	
	If IsBlankString(Title) Then
		Title = NStr("en='Note';ru='Примечание'");
	EndIf;
	
	SourceParameters = New Structure;
	SourceParameters.Insert("FormOrHandler", FormOrHandler);
	SourceParameters.Insert("PropsOwner",  PropsOwner);
	SourceParameters.Insert("AttributeName",       AttributeName);
	Handler = New NotifyDescription("EditMultilinedTextEnd", ThisObject, SourceParameters);
	
	ShowInputString(Handler, EditText, Title, , True);
	
EndProcedure

// Procedure work result handler EditMultilineText.
Procedure EditMultilinedTextEnd(Text, SourceParameters) Export
	
	If TypeOf(SourceParameters.FormOrHandler) = Type("ManagedForm") Then
		Form      = SourceParameters.FormOrHandler;
		Handler = Undefined;
	Else
		Form      = Undefined;
		Handler = SourceParameters.FormOrHandler;
	EndIf;
	
	If Text <> Undefined Then
		
		If TypeOf(SourceParameters.PropsOwner) = Type("FormDataTreeItem")
			Or TypeOf(SourceParameters.PropsOwner) = Type("FormDataCollectionItem") Then
			FillPropertyValues(SourceParameters.PropsOwner, New Structure(SourceParameters.AttributeName, Text));
		Else
			SourceParameters.PropsOwner[SourceParameters.AttributeName] = Text;
		EndIf;
		
		If Form <> Undefined Then
			If Not Form.Modified Then
				Form.Modified = True;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Handler <> Undefined Then
		ExecuteNotifyProcessing(Handler, Text);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Opens the additional report form with the specified option.
//
// Parameters:
//   Variant - Structure - Information about report variant:
//       * Ref - CatalogRef.ReportsVariants - Ref of report variant.
//       * Report - <see. Catalogs.ReportsVariants.Attributes.Report> - Ref or report name.
//       * VariantKey - String - Report variant name.
//
Procedure OpenAdditionalReportVariants(Variant) Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalreportsAndDataProcessorsClient = CommonUseClient.CommonModule("AdditionalReportsAndDataProcessorsClient");
		ModuleAdditionalreportsAndDataProcessorsClient.OpenAdditionalReportVariants(Variant.Report, Variant.VariantKey);
	EndIf;
	
EndProcedure

#EndRegion
