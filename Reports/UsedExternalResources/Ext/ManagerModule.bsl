#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceApplicationInterface

// Placement settings in the report panel.
//
// Parameters:
//   Settings - Collection - Used for the description of report
//       settings and variants, see description to ReportsVariants.ConfigurationReportVariantsSettingTree().
//   ReportSettings - ValueTreeRow - Placement settings of all report variants.
//      See "Attributes for change" of the ReportsVariants function.ConfigurationReportVariantsSetupTree().
//
// Description:
//  See ReportsVariantsOverridable.SetReportsVariants().
//
// Auxiliary methods:
//   VariantSettings = ReportsVariants.VariantDesc(Settings, ReportSettings, "<VariantName>");
//   ReportsVariants.SetOutputModeInReportPanels
//   False (Settings, ReportSettings,True/False); Repor//t supports only this mode.
//
Procedure ConfigureReportsVariants(Settings, ReportSettings) Export
	ReportSettings.Description = NStr("en = 'External Resources used by the application and additional modules'");
	ReportSettings.DefineFormSettings = True;
	ReportSettings.SearchSettings.FieldNames = 
		NStr("en = 'Name and
		|ID of
		|the
		|COM class
		|Computer name
		|Address Data reading Data recording
		|Template or
		|component attachment file name
		|Check
		|sum Command
		|bar template Protocol Internet resource address Port'");
	ReportSettings.SearchSettings.ParametersAndFiltersNames = "";
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Only for internal use.
//
Function PresentationRequestsPermissionsToUseExternalResources(Val AdministrationOperations, Val AddedPermissionsDescription, Val DeletedPermissionsDescription, Val AsRequired = False) Export
	
	Template = GetTemplate("PermissionsPresentation");
	IndentArea = Template.GetArea("Indent");
	SpreadsheetDocument = New SpreadsheetDocument();
	
	AllSoftwareModules = New Map();
	
	For Each Description IN AdministrationOperations Do
		
		Refs = WorkInSafeModeService.RefFromPermissionsRegister(
			Description.SoftwareModuleType, Description.SoftwareModuleID);
		
		If AllSoftwareModules.Get(Refs) = Undefined Then
			AllSoftwareModules.Insert(Refs, True);
		EndIf;
		
	EndDo;
	
	For Each Description IN AddedPermissionsDescription Do
		
		Refs = WorkInSafeModeService.RefFromPermissionsRegister(
			Description.SoftwareModuleType, Description.SoftwareModuleID);
		
		If AllSoftwareModules.Get(Refs) = Undefined Then
			AllSoftwareModules.Insert(Refs, True);
		EndIf;
		
	EndDo;
	
	For Each Description IN DeletedPermissionsDescription Do
		
		Refs = WorkInSafeModeService.RefFromPermissionsRegister(
			Description.SoftwareModuleType, Description.SoftwareModuleID);
		
		If AllSoftwareModules.Get(Refs) = Undefined Then
			AllSoftwareModules.Insert(Refs, True);
		EndIf;
		
	EndDo;
	
	ModulesTable = New ValueTable();
	ModulesTable.Columns.Add("ApplicationModule", CommonUse.TypeDescriptionAllReferences());
	ModulesTable.Columns.Add("IsConfiguration", New TypeDescription("Boolean"));
	
	For Each KeyAndValue IN AllSoftwareModules Do
		String = ModulesTable.Add();
		String.ApplicationModule = KeyAndValue.Key;
		String.IsConfiguration = (KeyAndValue.Key = Catalogs.MetadataObjectIDs.EmptyRef());
	EndDo;
	
	ModulesTable.Sort("ThisIsConfiguration DESC");
	
	For Each ModulesTableString IN ModulesTable Do
		
		SpreadsheetDocument.Put(IndentArea);
		
		Properties = WorkInSafeModeService.PropertiesForPermissionsRegister(
			ModulesTableString.ApplicationModule);
		
		Filter = New Structure();
		Filter.Insert("SoftwareModuleType", Properties.Type);
		Filter.Insert("SoftwareModuleID", Properties.ID);
		
		GenerateOperationsPresentation(SpreadsheetDocument, Template, AdministrationOperations.FindRows(Filter));
		
		ConfigurationProfile = (Properties.Type= Catalogs.MetadataObjectIDs.EmptyRef());
		
		If ConfigurationProfile Then
			
			Dictionary = ConfigurationModuleDictionary();
			ModuleName = Metadata.Synonym;
			
		Else
			
			ApplicationModule = WorkInSafeModeService.RefFromPermissionsRegister(
				Properties.Type, Properties.ID);
			
			ExternalModuleManager = WorkInSafeModeService.ExternalModuleManager(ApplicationModule);
			
			Dictionary = ExternalModuleManager.ExternalModuleContainerDictionary();
			Icon = ExternalModuleManager.ExternalModuleIcon(ApplicationModule);
			ModuleName = CommonUse.ObjectAttributeValue(ApplicationModule, "Description");
			
		EndIf;
		
		Adding = AddedPermissionsDescription.Copy(Filter);
		If Adding.Count() > 0 Then
			
			If AsRequired Then
				
				HeaderText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'For %1 ""%2"" it is required to use the following external resources:'"),
					Lower(Dictionary.Genitive),
					ModuleName);
				
			Else
				
				HeaderText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'For %1 ""%2"" the following permissions to use external resources will be granted:'"),
					Lower(Dictionary.Genitive),
					ModuleName);
				
			EndIf;
			
			Area = Template.GetArea("Header");
			
			Area.Parameters["HeaderText"] = HeaderText;
			If Not ConfigurationProfile Then
				
				Area.Parameters["ApplicationModule"] = ApplicationModule;
				Area.Parameters["Icon"] = Icon;
				
			EndIf;
			
			SpreadsheetDocument.Put(Area);
			
			SpreadsheetDocument.StartRowGroup(, True);
			
			SpreadsheetDocument.Put(IndentArea);
			
			GeneratePermissionPresentation(SpreadsheetDocument, Template, Adding, AsRequired);
			
			SpreadsheetDocument.EndRowGroup();
			
		EndIf;
		
		ToDelete = DeletedPermissionsDescription.Copy(Filter);
		If ToDelete.Count() > 0 Then
			
			If AsRequired Then
				Raise NStr("en = 'Incorrect request of permissions'");
			EndIf;
			
			HeaderText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'The following permissions for external resources use previously provided to %1 ""%2"" will be deleted:'"),
					Lower(Dictionary.Genitive),
					ModuleName);
			
			Area = Template.GetArea("Header");
			
			Area.Parameters["HeaderText"] = HeaderText;
			If Not ConfigurationProfile Then
				Area.Parameters["ApplicationModule"] = ApplicationModule;
				Area.Parameters["Icon"] = Icon;
			EndIf;
			
			SpreadsheetDocument.Put(Area);
			
			SpreadsheetDocument.StartRowGroup(, True);
			
			GeneratePermissionPresentation(SpreadsheetDocument, Template, ToDelete, False);
			
			SpreadsheetDocument.EndRowGroup();
			
		EndIf;
		
		If Adding.Count() > 0 Or ToDelete.Count() > 0 Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generates presentation of permission administration operations for external resources use.
//
// Parameters:
//  SpreadsheetDocument - TabularDocument that will
//  display operations, Template - TabularDocument received from
//  report template PermissionsPresentation, AdministrationOperations - ValuesTable,
//                              see DataProcessors.PermissionSettingsForExternalResourcesUse.AdministrationOperationsInQueries().
//
Procedure GenerateOperationsPresentation(SpreadsheetDocument, Val Template, Val AdministrationOperations)
	
	For Each Description IN AdministrationOperations Do
		
		If Description.Operation = Enums.OperationsAdministrationSecurityProfiles.Delete Then
			
			ConfigurationProfile = (Description.SoftwareModuleType = Catalogs.MetadataObjectIDs.EmptyRef());
			
			If ConfigurationProfile Then
				
				Dictionary = ConfigurationModuleDictionary();
				ModuleName = Metadata.Synonym;
				
			Else
				
				ApplicationModule = WorkInSafeModeService.RefFromPermissionsRegister(
					Description.SoftwareModuleType, Description.SoftwareModuleID);
				Dictionary = WorkInSafeModeService.ExternalModuleManager(ApplicationModule).ExternalModuleContainerDictionary();
				ModuleName = CommonUse.ObjectAttributeValue(ApplicationModule, "Description");
				
			EndIf;
			
			HeaderText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'Security profile for %1 ""%2"" will be deleted.'"),
					Lower(Dictionary.Genitive),
					ModuleName);
			
			Area = Template.GetArea("Header");
			
			Area.Parameters["HeaderText"] = HeaderText;
			If Not ConfigurationProfile Then
				Area.Parameters["ApplicationModule"] = ApplicationModule;
			EndIf;
			Area.Parameters["Icon"] = PictureLib.Delete;
			
			SpreadsheetDocument.Put(Area);
			
			SpreadsheetDocument.PutHorizontalPageBreak();
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Generates presentation of permissions.
//
// Parameters:
//  SpreadsheetDocument - SpreadsheetDocument - document which will display
//  operations, PermissionsSets - Structure - see DataProcessors.PermissionSettingsForExternalResourcesUse.PermissionsTables(),
//  Template - SpreadsheetDocument - document received from report
//  template PermissionsPresentation, AsRequired - Boolean - use flag in presentation of terms of the type
//                          "the following resources are required" instead of "the following resources will be provided".
//
Procedure GeneratePermissionPresentation(Val SpreadsheetDocument, Val Template, Val PermissionsSets, Val AsRequired = False)
	
	IndentArea = Template.GetArea("Indent");
	
	Types = PermissionsSets.Copy();
	Types.GroupBy("Type");
	Types.Columns.Add("Order", New TypeDescription("Number"));
	
	SortingOrder = PermissionTypesSortingOrder();
	For Each TypeRow IN Types Do
		TypeRow.Order = SortingOrder[TypeRow.Type];
	EndDo;
	
	Types.Sort("Order ASC");
	
	For Each TypeRow IN Types Do
		
		DefinitionType = TypeRow.Type;
		
		Filter = New Structure();
		Filter.Insert("Type", TypeRow.Type);
		PermissionsStrings = PermissionsSets.FindRows(Filter);
		
		Count = 0;
		For Each PermissionsString IN PermissionsStrings Do
			Count = Count + PermissionsString.permissions.Count();
		EndDo;
		
		If Count > 0 Then
			
			GroupArea = Template.GetArea("Group" + DefinitionType);
			FillPropertyValues(GroupArea.Parameters, New Structure("Count", Count));
			SpreadsheetDocument.Put(GroupArea);
			
			SpreadsheetDocument.StartRowGroup(DefinitionType, True);
			
			HeaderArea = Template.GetArea("Header" + DefinitionType);
			SpreadsheetDocument.Put(HeaderArea);
			
			RowArea = Template.GetArea("String" + DefinitionType);
			
			For Each PermissionsString IN PermissionsStrings Do
				
				For Each KeyAndValue IN PermissionsString.permissions Do
					
					Resolution = CommonUse.ObjectXDTOFromXMLRow(KeyAndValue.Value);
					
					If DefinitionType = "AttachAddin" Then
						
						FillPropertyValues(RowArea.Parameters, Resolution);
						SpreadsheetDocument.Put(RowArea);
						
						SpreadsheetDocument.StartRowGroup(Resolution.TemplateName);
						
						AuthorizationAdding = PermissionsString.PermissionsAdditions.Get(KeyAndValue.Key);
						If AuthorizationAdding = Undefined Then
							AuthorizationAdding = New Structure();
						Else
							AuthorizationAdding = CommonUse.ValueFromXMLString(AuthorizationAdding);
						EndIf;
						
						For Each AdditionKeyAndValue IN AuthorizationAdding Do
							
							FileStringArea = Template.GetArea("RowAttachAddinAdditional");
							
							FillPropertyValues(FileStringArea.Parameters, AdditionKeyAndValue);
							SpreadsheetDocument.Put(FileStringArea);
							
						EndDo;
						
						SpreadsheetDocument.EndRowGroup();
						
					Else
						
						AuthorizationAdding = New Structure();
						
						If DefinitionType = "FileSystemAccess" Then
							
							If Resolution.Path = "/temp" Then
								AuthorizationAdding.Insert("Path", NStr("en = 'Temporary files directory'"));
							EndIf;
							
							If Resolution.Path = "/bin" Then
								AuthorizationAdding.Insert("Path", NStr("en = 'Directory in which server 1C:Enterprise is installed.'"));
							EndIf;
							
						EndIf;
						
						FillPropertyValues(RowArea.Parameters, Resolution);
						FillPropertyValues(RowArea.Parameters, AuthorizationAdding);
						
						SpreadsheetDocument.Put(RowArea);
						
					EndIf;
					
				EndDo;
				
			EndDo;
			
			SpreadsheetDocument.EndRowGroup();
			
			SpreadsheetDocument.Put(IndentArea);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns the dictionary of configuration properties.
//
// Return value: Structure:
//                         * Nominative - module type synonym in
//                         the nominative case, * Genitive - module type synonym in the genitive case.
//
Function ConfigurationModuleDictionary() Export
	
	Result = New Structure();
	
	Result.Insert("Nominative", NStr("en = 'Application'"));
	Result.Insert("Genitive", NStr("en = 'application'"));
	
	Return Result;
	
EndFunction

// Only for internal use.
//
Function PermissionTypesSortingOrder()
	
	Result = New Structure();
	
	Result.Insert("FileSystemAccess", 1);
	Result.Insert("CreateComObject", 2);
	Result.Insert("AttachAddin", 3);
	Result.Insert("RunApplication", 4);
	Result.Insert("InternetResourceAccess", 5);
	Result.Insert("ExternalModulePrivilegedModeAllowed", 6);
	
	Return New FixedStructure(Result);
	
EndFunction

#EndRegion

#EndIf